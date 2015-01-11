require "yaml"

class ReplayableOperationTest < Minitest::Test
  include Examples::InvitationService::TestSetup

  def test_replaying_an_operation_from_a_previous_recording
    # Execute the operation against real services, saving a recording
    recording = execute_for_real

    # Write the recording out to a file. In this case, a StringIO is used for
    # simplicity, and we serialize into JSON. The to_h is important as
    # hashes can be coerced back into Recording objects.
    file = StringIO.new
    file.write JSON.dump recording
    file.rewind

    # Re-load the recording from JSON using Orchestra::Recording()
    parsed_json = JSON.parse file.read, symbolize_names: true
    recording = Orchestra::Recording(parsed_json)

    # Replay the operation, directing SMTP to an alternative service object
    smtp_service = build_example_smtp
    recording.replay(
      Examples::InvitationService,
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

    conductor = Orchestra::Conductor.new(
      :db   => db,
      :http => Net::HTTP,
      :smtp => mock_smtp,
    )

    recording = conductor.record(
      Examples::InvitationService,
      :account_name => 'realntl',
    )

    db.close

    recording
  end
end
