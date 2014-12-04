class InvokerTest < Minitest::Test
  def test_defaults_to_single_thread
    invoker = Orchestra::Invoker.new

    assert_equal 1, invoker.thread_count
  end

  def test_configuring_thread_pool_globally
    Orchestra.configure do |defaults|
      defaults.thread_count = 5
    end

    invoker = Orchestra::Invoker.new

    assert_equal 5, invoker.thread_count
  end

  def test_configuring_thread_pool_on_an_instance
    invoker = Orchestra::Invoker.new

    invoker.thread_count = 5

    assert_equal 5, invoker.thread_count
  end
end
