require 'json'

Flutter = Orchestra.define_operation do
  node :collect_flutter_followers do
    depends_on :account_name, :http
    provides :follower_list
    perform do
      response = http.get "flutter.io", "/users/#{account_name}/followers"
      followers = JSON.parse response
      followers.map do |follower|
        { account_name: follower['username'], email: follower['email_address'] }
      end
    end
  end

  node :fetch_follower_rating do
    depends_on :db, :follower_list
    provides :follower_ratings
    perform do |follower|
      account_names = follower_list.map do |hsh| hsh.fetch :account_name end
      group = account_names.map &:inspect
      ratings_by_follower = db.execute "SELECT AVG(rating), account_name FROM ratings WHERE account_name IN (#{group.join ', '}) GROUP BY account_name"
      ratings_by_follower.each_with_object Hash.new do |row, hsh|
        hsh[row.fetch 1] = row.fetch 0
      end
    end
  end

  node :filter_followers do
    depends_on :follower_ratings, :minimum_rating => 4.0
    iterates_over :follower_list
    provides :email_addresses
    perform do |follower|
      account_name = follower.fetch :account_name
      rating = follower_ratings.fetch account_name, 0
      next unless rating > minimum_rating
      follower.fetch :email
    end
  end

  self.result = :email_addresses
end

def Flutter.test_setup
  @mod ||= Module.new do
    private

    def build_example_database
      db = SQLite3::Database.new ':memory:'
      db.execute <<-SQL
        CREATE TABLE ratings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_name VARCHAR(255),
          rating INTEGER
        )
      SQL
      db.execute 'INSERT INTO ratings(account_name,rating) VALUES("mister_ed",4)'
      db.execute 'INSERT INTO ratings(account_name,rating) VALUES("mister_ed",3)'
      db.execute 'INSERT INTO ratings(account_name,rating) VALUES("captain_sheridan",5)'
      db.execute 'INSERT INTO ratings(account_name,rating) VALUES("captain_sheridan",4)'
      db.execute 'INSERT INTO ratings(account_name,rating) VALUES("palpatine4",2)'
      db
    end

    def stub_followers_request response_hsh = default_followers_request
      followers_stub = stub_request :get, "http://flutter.io/users/realntl/followers"
      followers_stub.to_return :body => response_hsh.to_json
      followers_stub.times 1
      followers_stub
    end

    def default_followers_request
      [
        { 'username' => 'mister_ed', 'email_eddress' => 'ed@mistered.com' },
        { 'username' => 'captain_sheridan', 'email_address' => 'captain_sheridan@babylon5.earth.gov' },
      ]
    end
  end
end
