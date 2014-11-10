require 'json'

Flutter = Orchestra.define_operation do
  node :collect_flutter_followers do
    depends_on :account_name, :http_interface
    provides :follower_list
    perform do
      response = http_interface.get "https://flutter.io/users/#{account_name}/followers"
      followers = JSON.parse response
      followers.each_with_object [] do |follower|
        { account_name: follower[:account_name], email: follower[:email] }
      end
    end
  end

  node :fetch_follower_rating do
    depends_on :db_interface
    iterates_over :follower_list
    provides :follower_ratings
    perform do |follower|
      account_names = follower_list.map { |hsh| hsh.fetch :account_name }
      ratings_by_follower = db.exec "SELECT AVG(rating), account_name FROM ratings WHERE account_name IN (?) GROUP BY account_name", account_names
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

  self.result = :filter_followers
end

Flutter.instance_eval do
  def populate_database db
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
  end
end
