class RecordingTelemetryTest < Minitest::Test
  include Flutter.test_setup

  def setup
    stub_followers_request
  end

  def test_recording_telemetry
    telemetry = {}

    perform_with_telemetry telemetry

    assert_equal_telemetry expected_telemetry, telemetry
  end

  def test_recording_exceptions
    telemetry = {}

    error = assert_raises ArgumentError do
      perform_with_telemetry telemetry, build_example_database.dup
    end

    assert_equal "Flutter", telemetry[:performance_name]
    assert_equal "prepare called on a closed database", telemetry[:error].message
  end

  private

  def assert_equal_telemetry expected, actual
    expected.keys.each do |key|
      assert_equal expected[key], actual[key]
    end
  end

  def perform_with_telemetry telemetry, db = build_example_database
    conductor = Orchestra::Conductor.new(
      :http => Net::HTTP,
      :db   => db,
    )

    conductor.add_observer TelemetryRecorder.new telemetry

    conductor.perform(
      Flutter,
      :account_name => "realntl",
    )
  end

  def expected_telemetry
    {
      :performance_name => "Flutter",
      :input => { :account_name => "realntl" },

      :movements => {
        :collect_flutter_followers => {
          :input => {
            :account_name => "realntl",
          },
          :output => {
            :follower_list => [{:account_name=>"mister_ed", :email=>nil}, {:account_name=>"captain_sheridan", :email=>"captain_sheridan@babylon5.earth.gov"}],
          },
        },
        :fetch_follower_rating => {
          :input => {
            :follower_list => [{:account_name=>"mister_ed", :email=>nil}, {:account_name=>"captain_sheridan", :email=>"captain_sheridan@babylon5.earth.gov"}],
          },
          :output => {
            :follower_ratings => { "captain_sheridan" => 4.5, "mister_ed" => 3.5 },
          },
        },
        :filter_followers => {
          :input => {
            :follower_list => [{:account_name=>"mister_ed", :email=>nil}, {:account_name=>"captain_sheridan", :email=>"captain_sheridan@babylon5.earth.gov"}],
            :follower_ratings => { "captain_sheridan" => 4.5, "mister_ed" => 3.5 },
          },
          :output => {
            :email_addresses => ['captain_sheridan@babylon5.earth.gov'],
          },
        },
      },

      :service_calls => [
        {
          :service => :http,
          :method  => "get",
          :input   => ["flutter.io", "/users/realntl/followers"],
          :output  => "[{\"username\":\"mister_ed\",\"email_eddress\":\"ed@mistered.com\"},{\"username\":\"captain_sheridan\",\"email_address\":\"captain_sheridan@babylon5.earth.gov\"}]",
        },{
          :service => :db,
          :method  => "execute",
          :input   => ["SELECT AVG(rating), account_name FROM ratings WHERE account_name IN (\"mister_ed\", \"captain_sheridan\") GROUP BY account_name"],
          :output  => [[4.5, "captain_sheridan"], [3.5, "mister_ed"]],
        },
      ],
    }
  end

  class TelemetryRecorder
    def initialize store
      @store = store
      @current_operation = nil
    end

    def update message, *payload
      method = "handle_#{message}"
      public_send method, *payload if respond_to? method
    end

    def handle_performance_started operation_name, input
      @nodes = Hash.new do |hsh, key| hsh[key] = {} end
      @store.update(
        :input => input,
        :movements => @nodes,
        :performance_name => operation_name,
        :service_calls => [],
      )
    end

    def handle_node_entered name, input
      @nodes[name][:input] = input
    end

    def handle_node_exited name, output
      @nodes[name][:output] = output
    end

    def handle_error_raised error
      @store[:error] = error
    end

    def handle_service_accessed service_name, record
      @store[:service_calls].<< record.merge :service => service_name
    end
  end
end
