class ConductorTest < Minitest::Test
  def test_defaults_to_single_thread
    conductor = Orchestra::Conductor.new

    assert_equal 1, conductor.thread_count
  end

  def test_configuring_thread_pool_globally
    Orchestra.configure do |defaults|
      defaults.thread_count = 5
    end

    conductor = Orchestra::Conductor.new

    assert_equal 5, conductor.thread_count
  end

  def test_configuring_thread_pool_on_an_instance
    conductor = Orchestra::Conductor.new

    conductor.thread_count = 5

    assert_equal 5, conductor.thread_count
  end
end
