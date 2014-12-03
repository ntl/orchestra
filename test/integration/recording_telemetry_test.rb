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
      :output => [],
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
end
