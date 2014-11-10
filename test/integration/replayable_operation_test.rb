class ReplayableOperationTest < Minitest::Test
  def test_performance
    stub_followers_request []
    db = build_example_database

    conductor = Orchestra::Conductor.new(
      http_interface: Net::HTTP,
      db_interface: db,
    )

    result = conductor.perform(
      Flutter,
      inputs: {
        account_name: 'realntl'
      },
    )

    assert_equal ["captain_sheridan@babylon5.earth.gov"], result
  end

  private

  def build_example_database
    db = SQLite3::Database.new ':memory:'
    Flutter.populate_database db
    db
  end

  def stub_followers_request response_hsh
    followers_stub = stub_request :get, "flutter.io/users/realntl/followers"
    followers_stub.to_return :body => response_hsh.to_json
  end
end
