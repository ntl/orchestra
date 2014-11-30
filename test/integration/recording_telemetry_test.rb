class RecordingTelemetryTest < Minitest::Test
  def test_recording_telemetry
    output = StringIO.new
    telemetry = {}

    perform_with_telemetry telemetry, output

    assert_equal_telemetry expected_telemetry, telemetry
  end

  private

  def assert_equal_telemetry expected, actual
    expected.keys.each do |key|
      assert_equal expected[key], actual[key]
    end
  end

  def expected_telemetry
    {
      :input => { :up_to => 16 },
      :movements => {
        :make_array => {
          :input  => { :up_to => 16 },
          :output => { :array => [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15] },
        },
        :apply_fizzbuzz => {
          :input  => { :array => [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15] },
          :output => {
            :fizzbuzz => [
              "1",
              "2",
              "Fizz",
              "4",
              "Buzz",
              "Fizz",
              "7",
              "8",
              "Fizz",
              "Buzz",
              "11",
              "Fizz",
              "13",
              "14",
              "FizzBuzz",
            ],
          },
        },
        :print => {
          :input => {
            :fizzbuzz => [
              "1",
              "2",
              "Fizz",
              "4",
              "Buzz",
              "Fizz",
              "7",
              "8",
              "Fizz",
              "Buzz",
              "11",
              "Fizz",
              "13",
              "14",
              "FizzBuzz",
            ],
          },
          :output => { :print => [] },
        }
      },
      :output => nil,
    }
  end

  def perform_with_telemetry telemetry, io
    conductor = Orchestra::Conductor.new :io => io

    conductor.add_observer TelemetryRecorder.new telemetry

    conductor.perform(
      Examples::FizzBuzz,
      :up_to => 16,
    )
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
