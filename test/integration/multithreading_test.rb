class MultithreadingTest < Minitest::Test
  CustomError = Class.new StandardError

  def setup
    @operation = Orchestra::Operation.new do
      step :map_thread_ids do
        iterates_over :list
        provides :thread_ids
        execute do |item|
          raise CustomError, "blow up" if item == :blow_up
          Thread.current.object_id
        end
      end

      self.result = :thread_ids
    end

    @conductor = Orchestra::Conductor.new
    @conductor.thread_count = 5
  end

  def test_multithreading
    list = (1..1000).to_a

    thread_ids = @conductor.execute @operation, :list => list

    assert_equal(
      @conductor.thread_count,
      thread_ids.uniq.size,
      "execution must be spread across threads",
    )
  end

  def test_exception_during_multithreading
    list = (1..50).to_a
    list[23] = :blow_up

    assert_raises CustomError do
      @conductor.execute @operation, :list => list
    end
  end
end
