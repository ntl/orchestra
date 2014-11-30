module Examples
  InvitationService = Orchestra.define_operation do
    DEFAULT_MESSAGE = "I would really love for you to try out MyApp."
    ROBOT_FOLLOWER_THRESHHOLD = 500

    node :fetch_followers do
      depends_on :account_name, :http
      provides :followers
      perform do
        json = http.get "flutter.io", "/users/#{account_name}/followers"
          JSON.parse json
      end
    end

    node :fetch_blacklist do
      depends_on :db
      provides :blacklist
      perform do
        rows = db.execute "SELECT account_name FROM blacklists"
        rows.map do |row| row.fetch 0 end
      end
    end

    node :remove_blacklisted_followers do
      depends_on :blacklist
      modifies :followers
      perform do
        followers.reject! do |follower|
          account_name = follower.fetch 'username'
          blacklist.include? account_name
        end
      end
    end

    node :filter_robots do
      depends_on :http
      modifies :followers, :collection => true
      perform do |follower|
        account_name = follower.fetch 'username'
        json = http.get "flutter.io", "/users/#{account_name}"
        account = JSON.load json
        next unless account['following'] > ROBOT_FOLLOWER_THRESHHOLD
        next unless account['following'] > (account['followers'] / 2)
        follower
      end
    end

    finally :deliver_emails do
      depends_on :smtp, :message => DEFAULT_MESSAGE
      iterates_over :followers
      perform do |follower|
        email = follower.fetch 'email_address'
        smtp.deliver message, :to => email
      end
    end
  end

  module InvitationService::TestSetup
    private

    def build_example_database
      db = SQLite3::Database.new ':memory:'
      db.execute <<-SQL
      CREATE TABLE blacklists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_name VARCHAR(255)
      )
      SQL
      db.execute 'INSERT INTO blacklists(account_name) VALUES("mister_ed")'
      db.execute 'INSERT INTO blacklists(account_name) VALUES("palpatine4")'
      db
    end

    def build_example_smtp
      SMTPCatcher.new
    end

    def stub_accounts_requests
      requests = {
        'mister_ed'        => { 'following' => 5192,  'followers' => 4820 },
        'captain_sheridan' => { 'following' => 12840, 'followers' => 523  },
      }

      requests.each do |account_name, response|
        stub = stub_request :get, "http://flutter.io/users/#{account_name}"
        stub.to_return :body => response.to_json
        stub.times 1
        stub
      end
    end

    def stub_followers_request
      response = [
        { 'username' => 'mister_ed', 'email_address' => 'ed@mistered.com' },
        { 'username' => 'captain_sheridan', 'email_address' => 'captain_sheridan@babylon5.earth.gov' },
      ]

      followers_stub = stub_request :get, "http://flutter.io/users/realntl/followers"
      followers_stub.to_return :body => response.to_json
      followers_stub.times 1
      followers_stub
    end

    class SMTPCatcher
      attr :delivered

      def initialize
        @delivered = {}
      end

      def deliver message, args = {}
        recipient, _ = Orchestra::Util.extract_key_args args, :to
        delivered[recipient] = message
      end
    end

  end
end
