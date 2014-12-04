class ReplayableOperationTest < Minitest::Test
  include Examples::InvitationService::TestSetup

  def test_replaying_an_operation_from_a_previous_recording
    # Execute the operation against real services, saving a recording
    recording = execute_for_real

    # Write the recording out to a file. In this case, a StringIO is used for
    # simplicity, and we serialize into JSON
    file = StringIO.new
    file.write JSON.dump recording
    file.rewind

    # Replay the operation, directing SMTP to an alternative service object
    smtp_service = build_example_smtp
    Orchestra.replay_recording(
      Examples::InvitationService,
      JSON.load(file.read),
      :smtp => smtp_service,
    )

    # While replaying, the operation delivered all email using the alterantive
    # SMTP service object we passed in
    assert_equal(
      ["captain_sheridan@babylon5.earth.gov"],
      smtp_service.delivered.keys,
    )
  end

  private

  def execute_for_real
    mock_smtp = build_example_smtp
    db = build_example_database
    stub_followers_request
    stub_accounts_requests

    invoker = Orchestra::Invoker.new(
      :db   => db,
      :http => Net::HTTP,
      :smtp => mock_smtp,
    )

    recording = invoker.record(
      Examples::InvitationService,
      :account_name => 'realntl',
    )

    db.close

    recording
  end
end
