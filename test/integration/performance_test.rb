class PerformanceTest < Minitest::Test
  def test_batch_operations_are_parallelized
    skip unless ENV['BENCH']
    serial = calc 1
    parallel = calc 4

    assert_in_epsilon(
      (serial / 4),
      parallel,
      0.2,
      "four way parallel execution ought to be four cores faster",
    )
  end

  private

  def calc thread_count
    queue = Queue.new

    threads = thread_count.times.map do
      Thread.new queue do |queue|
        Thread.current.abort_on_exception = true
        while num = queue.pop
          calc_fib num
        end
      end
    end

    count = 100 / thread_count
    nums = count.times do queue << 30 end

    t1 = Time.now
    thread_count.times { queue << nil }
    threads.map &:join
    t2 = Time.now

    t2 - t1
  end

  def calc_fib num
    if num <= 2
      1
    else
      calc_fib(num - 2) + calc_fib(num - 1)
    end
  end

end
