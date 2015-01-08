# Orchestra ![Build Status](https://travis-ci.org/ntl/orchestra.svg?branch=master)

Seamlessly chain multiple command or query objects together with a simple, lightweight framework.

## Usage

Here's a simple example without a lot of context:

```ruby
operation = Orchestra::Operation.new do
  step :make_array do
    depends_on :up_to
    provides :array
    execute do
      limit.times.to_a
    end
  end

  step :apply_fizzbuzz do
    iterates_over :array
    provides :fizzbuzz
    execute do |num|
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
    execute do |str|
      puts str
    end
  end
end

Orchestra.execute operation, :up_to => 31
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
[1] pry(Orchestra)> Orchestra.execute FizzBuzz, :up_to => 31
[1] pry(Orchestra)> Orchestra.execute InvitationService, :account_name => 'realntl`
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

Another problem is that because `InvitationService` directly calls out to external services through `FlutterAPI` (an HTTP gatewary) and `Blacklist` (an `ActiveRecord` class), the only way to determine exactly what happened during an invokation of `InvitationService#call` is to know exactly what those API calls returned. This often means having to pull down production databases and API credentials in order to debug specific failure cases. And that doesn't even begin to scratch the surface of how painful an object like `InvitationService` is to test. You have to shove a bunch of fabricated records into a database and mock all of the API calls to `FlutterAPI`.

As your application matures, you'll find that your test environment begins diverging significantly from your production environment. Confidence in your test suite drops, and you have to resort to either pulling down production state or logging into a rails console on a production system in order to debug problems. The difficulty of write automated tests for this "service object" and the need to constantly invoke the code within a production context are actually two facets of the same problem -- your code is coupled to your environment.

Objects like `InvitationService` are not fun to work with.

## Wiring up an orchestration

Here is a simple translation of the above `InvitationService` into an orchestration:

```ruby
InvitationService = Orchestra::Operation.new do
  DEFAULT_MESSAGE = "I would really love for you to try out MyApp."
  ROBOT_FOLLOWER_THRESHHOLD = 500

  step :fetch_followers do
    depends_on :account_name
    provides :followers
    execute do
      FlutterAPI.get_account account_name
    end
  end

  step :fetch_blacklist do
    provides :blacklist
    execute do
      Blacklist.pluck :flutter_account_name
    end
  end

  step :remove_blacklisted_followers do
    depends_on :blacklist
    modifies :followers
    execute do
      followers.reject! do |follower|
        account_name = follower.fetch 'username'
        blacklist.include? account_name
      end
    end
  end

  step :filter_robots do
    modifies :followers, :collection => true
    execute do |follower|
      account_name = follower.fetch 'username'
      account = FlutterAPI.get_account account_name
      next unless account['following'] > ROBOT_FOLLOWER_THRESHHOLD
      next unless account['following'] > (account['followers'] / 2)
      follower
    end
  end

  finally :deliver_emails do
    depends_on :message => DEFAULT_MESSAGE
    iterates_over :followers
    execute do |follower|
      EmailDelivery.send message, :to => follower
    end
  end
end
```

At first sight, that very likely appears to be a giant pile of ruby DSL goop. And you would be correct. I'll show you how to plug in POROs in a bit, and there are some further improvements that will make the indirection worth while. For now, here is how you would execute this command:

```ruby
# Use the default message
Orchestra.execute InvitationService, :account_name => 'realntl'

# Override the default message
Orchestra.execute InvitationService, :account_name => 'realntl', :message => 'Say cheese!'
```

There's a lot more to learn, but let's start by building an understanding of the DSL.

## Breaking down the DSL: Steps

An *operation* is a collection of steps that each individually take part in producing some larger behavior. A step, essentially, accepts input, processes, and provides output. Let's look at the first one, called `:fetch_followers`.

```ruby
step :fetch_followers do
  depends_on :account_name
  provides :followers
  execute do
    FlutterAPI.get_account account_name
  end
end
```

This node depends on something called an `account_name`. This means you must supply `:account_name` when you execute the operation, otherwise, `:fetch_followers` won't work. `orchestra` ensures that your invokation can't commence without the required input:

```ruby
# Raises Orchestra::MissingInputError: Missing input :account_name
operation.execute
# Works correctly
operation.execute :account_name => 'realntl'
```

Dependencies can be optional. In the above example, `deliver_emails` defaults the `:message` input to `DEFAULT_MESSAGE`.

Often, you will need the output of one operation to feed into the input of another. The annotations `depends_on`, `iterates_over`, and `modifies` all describe the inputs, and `provides` describes the output. When `provides` is omitted, the name of the output is set to match the name of the step. Orchestra actually uses the annotations to sort the ordering of the steps at runtime to ensure that all dependencies are satisfied. In the above example, `remove_blacklisted_followers` would not execute before `fetch_blacklist`, no matter where their definitions were placed within the operation. Orchestra detects that `remove_blacklisted_followers` *depends on* `blacklist`, and `fetch_blacklist` actually provides a `blacklist`, so it knows to run `fetch_blacklist` before `remove_blacklisted_followers`. Similarly, if you had your own list of blacklisted account names lying around, you could bypass the `fetch_blacklist` step altogether, since there is no sense fetching a `blacklist` when you've already got one:

```ruby
# Never invokes fetch_blacklist
operation.execute :account_name => 'realntl', :blacklist => %w(dhh unclebobmartin)
```

This allows your operations to be reused in cases where some of the dependencies can already be satisfied.

Finally, the `modifies` annotiation deserves some explaining. When a step merely mutates an input, you are certainly welcome to declare distinct `depends_on` and `modifies` annotations:

```ruby
step :remove_blacklisted_followers do
  depends_on :blacklist, :followers
  provides :followers
end
```

However, `modifies` simply condenses the two into one. The following example is identical to the previous:

```ruby
step :remove_blacklisted_followers do
  depends_on :blacklist
  modifies :followers
end
```

## Breaking down the DSL: the operation itself

Configuring the operation is rather simple. You define the various steps, and then specify the result. There are three ways to specify the result.

The first is very straightforward:

```ruby
Orchestra::Operation.new do
  step :foo do
    depends_on :bar
    provides :foo # optional, since the step is called :foo
    execute do … end
  end

  self.result = :foo
end
```

The second is just a shortened form of the first:

```ruby
Orchestra::Operation.new do
  # Define a step called :foo and make it the result
  result :foo do
    depends_on :bar
    execute do … end
  end
end
```

The third is a minor variation of the second. The only difference is that the operation will always return `true`. `finally` makes sense for operations that execute side effects (e.g. Command objects), whereas `result` will make sense for queries.

```ruby
Orchestra::Operation.new do
  finally :foo do
    depends_on :bar
    execute do … end
  end
end
```

## Hooking in POROs

You can also hook up POROs to operations as steps. This is important both to manage complex steps as well as leveraging existing objects in the system. The `filter_robots` step could be expressed as a PORO rather easily:

```ruby
step FilterRobots, :iterates_over => :followers, :collection => true

class FilterRobots
  def initialize followers
    @followers = followers
  end

  def execute follower
    account_name = follower.fetch 'account_name'
    account = FlutterAPI.get_account account_name
    next unless account['following'] > ROBOT_FOLLOWER_THRESHHOLD
    next unless account['following'] > (account['followers'] / 2)
    account_name
  end
end
```

Orchestra infers the dependencies from `FilterRobots#initialize`, and automatically instantiates the object for you during execution. You can alter the name of the method:

```ruby
step MyPoro, :method => :call
```

You can also hook into singletons like `Module` (or a `Class` that implements `self.execute`):

```ruby
step MySingleton, :method => :invoke

module MySingleton
  def self.invoke … end
end
```

By default, the name of the provision will be inferred from the object name.

## Multithreading

Two of the steps in the `InvitationService` orchestration -- `filter_robots` and `deliver_emails` -- actually operate on *collections*. `deliver_emails` indicates that `:followers` is a collection by using the `iterates_over` annotation instead of `depends_on`. In fact, the two annotations are identical *except* that `iterates_over` indicates that the dependency is in fact going to be a list. Collections can be defined on a `modifies` annotation, as well, by supplying `:collection => true` as in the case of `filter_robots`.

When steps iterate over collections, Orchestra invokes `execute do … end` block once for each item in the collection passed in. It also spreads out each invokation across a thread pool. By default, there is only one thread in the thread pool. You can reconfigure that globally in an initializer of some kind:

```ruby
Orchestra.configure do
  # Thread pools will spin up five threads
  self.thread_count = 5
end
```

These collections can operate as filters; the output list is a mapping of the input list *transformed* by the `execute` block. When the `execute` block returns `nil`, the output shrinks by one element. Consider the FizzBuzz example at the top of this document. Notice that `0` doesn't get printed out. This is because the `execute` block in `apply_fizzbuzz` returned nil when the `num` was zero. `nil` values get `compact`'ed.

## Invoking an operation through a conductor

Now that you understand how to define operations, we can do some cool things with them. First, though, we need to change the way we invoke operations. Let's instantiate a `Conductor`, and have *that* execute our operations for us:

```ruby
conductor = Orchestra::Conductor.new
conductor.execute InvitationService, :account_name => 'realntl'
```

What did that buy us? First, we can configure the size of the thread pool specifically for this conductor:

```ruby
conductor.thread_count = 5
```

Second, we can inject *services* into our operation. Our operation needs to be modified such that our database connections and API access are passed in as dependencies:

```ruby
step :fetch_followers do
  depends_on :account_name, :flutter_api
  provides :followers
  execute do
    flutter_api.get_account account_name
  end
end

# and

step :fetch_blacklist do
  depends_on :blacklist_table
  provides :blacklist
  execute do
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

We can also override the conductor's service registry by supplying them into the execution itself, as we do any other dependency like `account_name`:

```ruby
conductor.execute InvitationService, :account_name => 'realntl', :blacklist_table => mock
```

What did this buy us? Two big things. We can now attach *observers* to the execution, and we can actually record all calls in and out of the `flutter_api` and `blacklist_table` services. The former allows us to share the internal operation of the execution with the rest of the system without breaking encapsulation, and the latter allows us to actually replay the operation against recordings of live performances.

Additionally, you can pass the `conductor` into steps. In this way you can embed one operation inside another:

```ruby
inner_operation = Orchestra::Operation.new do
  result :foo do
    provides :bar
    execute do
      bar * 2
    end
  end
end

outer_operation = Orchestra::Operation.new do
  result :baz do
    depends_on :conductor
    provides :qux
    execute do
      conductor.execute inner_operation
    end
  end
end

conductor = Conductor.new
conductor.execute outer_operation
```

To shorten this, the inner operation can be "mounted" inside the outer operation:

```ruby
inner_operation = Orchestra::Operation.new do
  result :foo do
    provides :bar
    execute do
      bar * 2
    end
  end
end

outer_operation = Orchestra::Operation.new do
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
    when :operation_entered then "Hello"
    when :operation_exited then "World!"
    when :step_entered then "Hello from within a step"
    when :step_exited then "Goodbye from within a step"
    when :error_raised then "Ruh roh!"
    when :service_accessed then "Yay, service call"
    end
  end
end
```

The arguments passed to `update` will vary based on the event:

| Event                    | First argument          | Second argument                   |
| ------------------------ | ----------------------- | --------------------------------- |
| `:operation_entered`     | The Operation starting  | Input going into the operation    |
| `:operation_exited`      | The Operation finishing | Output of the operation           |
| `:step_entered`          | The Step                | Input going into the step         |
| `:step_exited`           | The Step                | Output of the step                |
| `:error_raised`          | The error itself        | `nil`                             |
| `:service_accessed`      | The name of the service | Recording of the service call     |

All observers attached to the execution of the outer operation will also attach to the inner operation.

## Recording and playing back services

The final main feature of Orchestra is the ability to record the service calls throughout an operation. These recordings can then be used to replay operations. This could be helpful, for instance, to attach to exceptions in your exception logging service so that programmers can replay failed executions on their development environments. In addition, these recordings could be used to drive integration testing. Thus, instead of using separate tools such as ActiveRecord fixtures, FactoryGirl, and VCR for every service dependency, you can test your operations with one single setup artifact.

You can record a performance put on by any `Conductor` by calling `#record` instead of `#execute`:

```ruby
recording = conductor.record InvitationService, :account_name => 'realntl'
recording.output # <-- the usual output is attached to the recording itself
```

And a recording can be replayed:

```ruby
Orchestra.replay_recording InvitationService, recording
```

You can override the inputs passed in when replaying:

```ruby
Orchestra.replay_recording InvitationService, recording, :account_name => "dhh"
```

If you want to serialize/persist the recording, just use `JSON.dump`:

```ruby
json = JSON.dump recording
File.write "/tmp/recording.json", json
```

You can replay the recording using `JSON.load`:

```ruby
json = File.read "tmp/recording.json"
recording = JSON.load json
Orchestra.replay_recording InvitationService, recording
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ntl-orchestra'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ntl-orchestra

## Contributing

1. Fork it ( https://github.com/[my-github-username]/orchestra/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
