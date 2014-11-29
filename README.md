# Orchestra

Seamlessly chain multiple command or query objects together with a simple, lightweight framework.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'orchestra'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install orchestra

## Usage

Here's a simple example without a lot of context:

```ruby
operation = Orchestra.define_operation do
  node :make_array do
    depends_on :up_to
    provides :array
    perform do
      limit.times.to_a
    end
  end

  node :apply_fizzbuzz do
    iterates_over :array
    provides :fizzbuzz
    perform do |num|
      next if num == 0 # filter 0 from the output
      str = ''
      str << "Fizz" if num.mod 3 == 0
      str << "Buzz" if num.mod 5 == 0
      str << num.to_s if str.empty?
      str
    end
  end

  finally do
    iterates_over :fizzbuzz
    perform do |str|
      puts str
    end
  end
end

Orchestra.perform operation, :up_to => 31
```

There is an easy way to take this gem for a test drive. Clone the repo, and at the project root:

```sh
bin/rake console
```

You can run the gem's tests from within the console with `rake`:

```sh
[1] pry(Orchestra)> rake
Run options: --seed 59938

# Running:

................................................

Finished in 0.379958s, 126.3298 runs/s, 1526.4845 assertions/s.

48 runs, 580 assertions, 0 failures, 0 errors, 0 skips
=> true
```

Also, you can access the examples:

```ruby
[1] pry(Orchestra)> Orchestra.perform FizzBuzz, :up_to => 31
[1] pry(Orchestra)> Orchestra.perform InvitationService, :account_name => 'realntl`
```

## Why?

Suppose your application, MyApp, allows users to email an invitation to share the app with all the users' followers on a popular social microblogging network. However, the application also maintains an internal database of known blacklist users who never wish to be emailed. In addition, the application uses a simple heuristic algorithm to filter out bots. From the users' perspective, this is all one feature, but it would be difficult to pack into a single class. A straightforward implementation might look something like this:

```ruby
class InvitationService
  DEFAULT_MESSAGE = "I would really love for you to try out MyApp."
  ROBOT_FOLLOWER_THRESHHOLD = 500

  attr :user, :message

  def initialize user, message = DEFAULT_MESSAGE
    @user = user
    @message = message
  end

  def call
    target_emails.each do |follower|
      EmailDelivery.send message, :to => follower
    end
  end

  private

  def target_emails
    filtered_followers.map do |account_name|
      account = FlutterAPI.get_account account_name
      account['email']
    end
  end

  def filtered_followers
    @filtered_followers ||= filter_robots(raw_followers - blacklisted_followers)
  end

  def raw_followers
    @raw_followers ||= FlutterAPI.get_followers account_name
  end

  def blacklisted_followers
    @blacklisted_followers ||= Blacklist.pluck :flutter_account_name
  end

  def filter_robots list
    list.reject! do |account_name|
      account = FlutterAPI.get_account account_name
      next unless account['following'] > ROBOT_FOLLOWER_THRESHHOLD
      account['following'] > (account['followers'] / 2)
    end
  end
end
```

Despite appearing to conform to many popular conventions, so-called "service objects" such as `InvitationService` often prove extremely painful to work with and maintain, for a litany of reasons. The primary problem is that visibility into the flow of logic through the object has been sacrificed in order to reduce the surface area of the public API. Initially, during development, this appears to be a win, since smaller public APIs mean both less coupling *and* an easier interface for the next programmer to learn. However, suppose `FlutterAPI.get_account` starts returning hashes without a `'following'` key; this will cause `#filter_robots` to begin failing without any obvious reason why. To make matters worse, in order to discover where in the process the exception occurred, you have to reverse engineer the order of the operations by walking through all the memoization in your mind.

Another problem is that because `InvitationService` directly call out to external services through `FlutterAPI` (an HTTP gatewary) and `Blacklist` (an `ActiveRecord` class), the only way to determine exactly what happened during an invokation of `InvitationService#call` is to know exactly what those API calls returned. This often means having to pull down production databases and API credentials in order to debug specific failure cases. And that doesn't even begin to scratch the surface of how painful an object like `InvitationService` is to test. You have to somehow get a bunch of recrods into a database and mock the API calls to `FlutterAPI`. As your application matures, you'll find that your test environment begins diverging significantly from your production environment. Confidence in your test suite drops, and you have to resort to either pulling down production state or logging into a rails console on a production system in order to debug production problems. The difficulty of write automated tests for this "service object" and the need to constantly invoke the code within a production context are actually two facets of the same problem -- your code is coupled to your environment.

Objects like `InvitationService` are not fun to work with.

## Wiring up an orchestration

Here is a simple translation of the above `InvitationService` into an orchestration:

```ruby
InvitationService = Orchestra.define_operation do
  DEFAULT_MESSAGE = "I would really love for you to try out MyApp."
  ROBOT_FOLLOWER_THRESHHOLD = 500

  node :fetch_followers do
    depends_on :account_name
    provides :followers
    perform do
      FlutterAPI.get_account account_name
    end
  end

  node :fetch_blacklist do
    provides :blacklist
    perform do
      Blacklist.pluck :flutter_account_name
    end
  end

  node :remove_blacklisted_followers do
    depends_on :blacklist
    modifies :followers
    perform do
      followers.reject! do |account_name|
        blacklist.include? account_name
      end
    end
  end

  node :filter_robots do
    modifies :followers, :collection => true
    perform do |account_name|
      account = FlutterAPI.get_account account_name
      next unless account['following'] > ROBOT_FOLLOWER_THRESHHOLD
      next unless account['following'] > (account['followers'] / 2)
      account_name
    end
  end

  finally :deliver_emails do
    depends_on :message => DEFAULT_MESSAGE
    iterates_over :followers
    perform do |follower|
      EmailDelivery.send message, :to => follower
    end
  end
end
```

At first sight, that very likely appears to be a giant pile of ruby DSL goop. And you would be correct. I'll show you how to plug in POROs in a bit, and there are some further improvements that will make the indirection worth while. For now, here is how you would perform this command:

```ruby
# Use the default message
Orchestra.perform InvitationService, :account_name => 'realntl'

# Override the default message
Orchestra.perform InvitationService, :account_name => 'realntl', :message => 'Say cheese!'
```

There's a lot more to learn, but let's start by building an understanding of the DSL.

## Breaking down the DSL: Nodes

An *operation* is a collection of nodes that each individually take part in producing some larger behavior. Each node represents one step, or stage, in the whole process. A node, essentially, accepts input, processes, and provides output. Let's look at the first node, called `:fetch_followers`.

```ruby
node :fetch_followers do
  depends_on :account_name
  provides :followers
  perform do
    FlutterAPI.get_account account_name
  end
end
```

This node depends on something called an `account_name`. This means you must supply `:account_name` when you perform the operation, otherwise, `:fetch_followers` won't work. `orchestra` ensures that your performance can't commence without the required input:

```ruby
 # Raises Orchestra::MissingInputError: Missing input :account_name
operation.perform
# Works correctly
operation.perform :account_name => 'realntl'
```

Dependencies can be optional. In the above example, `deliver_emails` defaults the `:message` input to `DEFAULT_MESSAGE`.

Often, you will need the output of one operation to feed into the input of another. The annotations `depends_on`, `iterates_over`, and `modifies` all describe the inputs, and `provides` describes the output. When `provides` is omitted, the name of the output is set to match the name of the node. Orchestra actually uses the annotations to sort the ordering of the nodes at runtime to ensure that all dependencies are satisfied. In the above example, `remove_blacklisted_followers` would not execute before `fetch_blacklist`, no matter where their definitions were placed within the operation. Orchestra detects that `remove_blacklisted_followers` *depends on* `blacklist`, and `fetch_blacklist` actually provides a `blacklist`, so it knows to run `fetch_blacklist` before `remove_blacklisted_followers`. Similarly, if you had your own list of blacklisted account names lying around, you could bypass the `fetch_blacklist` node altogether, since there is no sense fetching a `blacklist` when you've already got one:

```ruby
# Never invokes fetch_blacklist
operation.perform :account_name => 'realntl', :blacklist => %w(dhh unclebobmartin)
```

This allows your operations to be reused in cases where some of the dependencies can already be satisfied.

Finally, the `modifies` annotiation deserves some explaining. When a node merely mutates an input, you are certainly welcome to declare distinct `depends_on` and `modifies` annotations:

```ruby
node :remove_blacklisted_followers do
  depends_on :blacklist, :followers
  provides :followers
end
```

However, `modifies` simply condenses the two into one. The following example is identical to the previous:

```ruby
node :remove_blacklisted_followers do
  depends_on :blacklist
  modifies :followers
end
```

## Breaking down the DSL: the operation itself

Configuring the operation is rather simple. You define the various nodes, and then specify the result. There are three ways to specify the result.

The first is very straightforward:

```ruby
Orchestra.define_operation do
  node :foo do
    depends_on :bar
    provides :foo # optional, since the node is called :foo
    perform do … end
  end

  self.result = :foo
end
```

The second is just a shortened form of the first:

```ruby
Orchestra.define_operation do
  # Define a node called :foo and make it the result
  result :foo do
    depends_on :bar
    perform do … end
  end
end
```

The third is a minor variation of the second. The only difference is that the operation will always return `true`. `finally` makes sense for operations that perform side effects (e.g. Command objects), wherease `result` will make sense for queries.

```ruby
Orchestra.define_operation do
  finally :foo do
    depends_on :bar
    perform do … end
  end
end
```

## Hooking in POROs

You can also hook up POROs to operations as nodes. This is important both to manage complex nodes as well as leveraging existing objects in the system. The `filter_robots` node could be expressed as a PORO rather easily:

```ruby
node FilterRobots, :iterates_over => :followers, :collection => true

class FilterRobots
  def initialize followers
    @followers = followers
  end

  def perform account_name
    account = FlutterAPI.get_account account_name
    next unless account['following'] > ROBOT_FOLLOWER_THRESHHOLD
    next unless account['following'] > (account['followers'] / 2)
    account_name
  end
end
```

Orchestra infers the dependencies from `FilterRobots#initialize`, and automatically instantiates the object for you during the performance. You can alter the name of the method:

```ruby
node MyPoro, :method => :call
```

You can also hook into singletons like `Module` (or a `Class` that implements `self.perform`):

```ruby
node MySingleton, :method => :invoke

module MySingleton
  def self.invoke … end
end
```

By default, the name of the provision will be inferred from the object name.

## Multithreading

Two of the nodes in the `InvitationService` orchestration -- `filter_robots` and `deliver_emails` -- actually operate on *collections*. `deliver_emails` indicates that `:followers` is a collection by using the `iterates_over` annotation instead of `depends_on`. In fact, the two annotations are identical *except* that `iterates_over` indicates that the dependency is in fact going to be a list. Collections can be defined on a `modifies` annotation, as well, by supplying `:collection => true` as in the case of `filter_robots`.

When nodes iterate over collections, Orchestra invokes `perform do … end` block once for each item in the collection passed in. It also spreads out each invokation across a thread pool. By default, there is only one thread in the thread pool. You can reconfigure that globally in an initializer of some kind:

```ruby
Orchestra.configure do
  # Thread pools will spin up five threads
  self.thread_count = 5
end
```

These collections can operate as filters; the output list is a mapping of the input list *transformed* by the `perform` block. When the `perform` block returns `nil`, the output shrinks by one element. Consider the FizzBuzz example at the top of this document. Notice that `0` doesn't get printed out. This is because the `perform` block in `apply_fizzbuzz` returned nil when the `num` was zero. `nil` values get `compact`'ed.

## Invoking an operation through a conductor

Now that you understand how to define operations, we can do some cool things with them. First, though, we need to change the way we invoke operations. Let's instantiate a `Conductor`, and have *that* perform our operations for us:

```ruby
conductor = Orchestra::Conductor.new
conductor.perform InvitationService, :account_name => 'realntl'
```

What did that buy us? First, we can configure the size of the thread pool specifically for this conductor:

```ruby
conductor.thread_count = 5
```

Second, we can inject *services* into our operation. Our operation needs to be modified such that our database connections and API access are passed in as dependencies:

```ruby
node :fetch_followers do
  depends_on :account_name, :flutter_api
  provides :followers
  perform do
    flutter_api.get_account account_name
  end
end

# and

node :fetch_blacklist do
  depends_on :blacklist_table
  provides :blacklist
  perform do
    blacklist_table.pluck :flutter_account_name
  end
end
```

Now we can teach the conductor how to supply the services.

```ruby
conductor = Orchestra::Conductor.new(
  :flutter_api     => FlutterAPI,
  :blacklist_table => Blacklist,
)
```

We can also override the conductor's service registry by supplying them into the performance itself, as we do any other dependency like `account_name`:

```ruby
conductor.perform InvitationService, :account_name => 'realntl', :blacklist_table => mock
```

What did this buy us? Two big things. We can now attach *observers* to the performance, and we can actually record all calls in and out of the `flutter_api` and `blacklist_table` services. The former allows us to share the internal operation of the performance with the rest of the system without breaking encapsulation, and the latter allows us to actually replay the operation against recorded snapshots of live performances.

Additionally, you can pass the `conductor` into nodes. In this way you can embed one orchestration into another:

```ruby
inner_operation = Orchestra.define_operation do
  result :foo do
    provides :bar
    perform do
      bar * 2
    end
  end
end

outer_operation = Orchestra.define_operation do
  result :baz do
    depends_on :conductor
    provides :qux
    perform do
      conductor.perform inner_operation
    end
  end
end

conductor = Conductor.new
conductor.perform outer_operation
```

To shorten this, the inner operation can be "mounted" inside the outer operation:

```ruby
inner_operation = Orchestra.define_operation do
  result :foo do
    provides :bar
    perform do
      bar * 2
    end
  end
end

outer_operation = Orchestra.define_operation do
  result inner_operation
end
```

## Observing a performance

You can attach observers to any `Conductor`:

```ruby
conductor.add_observer MyObserver

class MyObserver
  def update event_name, *args
    case event_name
    when :performance_started then "Hello"
    when :performance_finished then "World!"
    when :node_entered then "Hello from within a node"
    when :node_exited then "Goodbye from within a node"
    when :error_raised then "Ruh roh!"
    end
  end
end
```

The arguments passed to `update` will vary based on the event:

| Event                    | First argument                       | Second argument                   |
| ------------------------ | ------------------------------------ | --------------------------------- |
| `:performance_started`   | The name of the operation starting   | Input going into the performance  |
| `:performance_finished`  | The name of the operation finishing  | Output of the performance         |
| `:node_entered`          | The name of the node                 | Input going into the node         |
| `:node_exited`           | The name of the node                 | Output of the node                |
| `:error_raised`          | The error itself                     | `nil`                             |

Embedded performances will inherit the observers of the outer operation.

## Recording and playing back services

The final main feature of Orchestra is the ability to record the service calls throughout an operation. These recordings can then be used to replay operations. This could be helpful, for instance, to attach to exceptions in your exception logging service so that programmers can replay failed performances on their development environments. In addition, these recordings could be used to drive integration testing. Thus, instead of using separate tools such as like ActiveRecord fixtures, FactoryGirl, and VCR for every service dependency, you can test your operations with one single setup artifact.

You can record a performance on any `Conductor`:

```ruby
recording = conductor.perform_with_recording InvitationService, :account_name => 'realntl'
recording.output # <-- the usual output is attached to the recording itself
```

And a recording can be replayed:

```ruby
Orchestra.replay_recording InvitationService, service_recording
```

If you want to serialize/persist the recording, just use `#to_h`:

```ruby
File.write "/tmp/recording.json", JSON.dump(recording.to_h)
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/orchestra/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
