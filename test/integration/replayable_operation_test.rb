class ReplayableOperationTest < Minitest::Test
  include Examples::InvitationService::TestSetup

  def test_replaying_an_operation_from_recording_object
    recording_object = perform_for_real
    smtp_service = replay_operation_from recording_object

    assert_equal(
      ["captain_sheridan@babylon5.earth.gov"],
      smtp_service.delivered.keys,
    )
  end

  def test_replaying_an_operation_from_hash
    recording_hash = perform_for_real.to_h
    smtp_service = replay_operation_from recording_hash

    assert_equal(
      ["captain_sheridan@babylon5.earth.gov"],
      smtp_service.delivered.keys,
    )
  end

  private

  def replay_operation_from(recording)
    smtp_service = build_example_smtp

    second_result = Orchestra.replay_recording(
      Examples::InvitationService,
      recording,
      :smtp => smtp_service,
    )
    smtp_service
  end

  def perform_for_real
    mock_smtp = build_example_smtp
    db = build_example_database
    stub_followers_request
    stub_accounts_requests

    conductor = Orchestra::Conductor.new(
      :db   => db,
      :http => Net::HTTP,
      :smtp => mock_smtp,
    )

    recording = conductor.perform_with_recording(
      Examples::InvitationService,
      :account_name => 'realntl',
    )

    db.close

    recording.to_h
  end
end
