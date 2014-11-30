class ReplayableOperationTest < Minitest::Test
  include Examples::InvitationService::TestSetup

  def test_replaying_an_operation
    recording = perform_for_real

    smtp_service = build_example_smtp

    second_result = Orchestra.replay_recording(
      Examples::InvitationService,
      recording,
      :smtp => smtp_service,
    )

    assert_equal(
      ["captain_sheridan@babylon5.earth.gov"],
      smtp_service.delivered.keys,
    )
  end

  private

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
