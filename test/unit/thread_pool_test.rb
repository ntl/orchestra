class ThreadPoolTest < Minitest::Test
  def setup
    @thread_pool = Orchestra::ThreadPool.new
    @thread_pool.count = 5
    @iterations = Integer(ENV['THREAD_POOL_ITERATIONS'] || 50)
  end

  def teardown
    @thread_pool.shutdown
  end

  def test_threads_are_spun_up_asleep
    expected_status = ['sleep'] * 5
    assert_equal expected_status, @thread_pool.status
  end

  def test_shutting_down
    @iterations.times do |idx|
      assert_equal 5, @thread_pool.count
      begin
        @thread_pool.shutdown
      rescue Timeout::Error
        flunk "Timeout on iteration #{idx}"
      end
      assert_equal 0, @thread_pool.count

      @thread_pool.count = 5
    end
  end

  def test_adjusting_thread_count_is_robust
    iterate = lambda { |delta|
      old_count = @thread_pool.count
      new_count = old_count + delta
      expected_status = ['sleep'] * new_count
      @thread_pool.count = new_count
      assert_equal expected_status, @thread_pool.status, "going from #{old_count} ⇒ #{new_count}"
    }

    # Add @iterations times
    @iterations.times do iterate.call 1 end

    # Remove @iterations times
    @iterations.times do iterate.call -1 end
  end

  def test_performing_work
    @iterations.times do
      result = @thread_pool.perform do :deadbeef end

      assert_equal :deadbeef, result
    end
  end

  def test_enqueueing_work
    jobs = @iterations.times.map do |num|
      @thread_pool.enqueue do (num + 1) * 2 end
    end

    result = jobs.map &:wait

    assert_equal @iterations,     result.uniq.size
    assert_equal 2,               result.first
    assert_equal @iterations * 2, result.last
  end

  def test_handling_exceptions
    Thread.current.abort_on_exception = false
    old_thread_count = @thread_pool.count

    input = @iterations.times.to_a
    input << nil

    10.times do
      assert_raises NoMethodError do
        input.each do |num|
          @thread_pool.perform do num * 2 end
        end
      end
    end

    assert_equal ['sleep'] * old_thread_count, @thread_pool.status
  end

  def test_observing_jobs
    observer = TestObserver.new

    job = @thread_pool.enqueue do 2 end
    job.add_observer observer
    job.wait

    assert_equal [:finished, "2"], observer.results
  end

  class TestObserver
    attr :results

    def initialize
      @results = []
    end

    def update event, payload
      @results = [event, payload.inspect]
    end
  end
end
