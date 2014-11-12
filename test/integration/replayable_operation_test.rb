class ReplayableOperationTest < Minitest::Test
  include Flutter.test_setup

  def test_replaying_an_operation
    service_recording = perform

    assert_equal ["captain_sheridan@babylon5.earth.gov"], service_recording[:output]

    second_result = Orchestra.replay_recording(
      Flutter,
      service_recording,
    )

    assert_equal ["captain_sheridan@babylon5.earth.gov"], second_result
  end

  private

  def perform
    db = build_example_database
    stub_followers_request

    conductor = Orchestra::Conductor.new(
      :http => Net::HTTP,
      :db   => db,
    )

    recording = conductor.perform_with_recording(
      Flutter,
      :account_name => 'realntl',
    )

    db.close

    recording.to_h
  end
end
