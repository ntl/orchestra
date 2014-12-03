class MultithreadingTest < Minitest::Test
  CustomError = Class.new StandardError

  def setup
    @operation = Orchestra::Operation.new do
      node :map_thread_ids do
        iterates_over :list
        provides :thread_ids
        perform do |item|
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
    list = (1..100).to_a

    thread_ids = @conductor.perform @operation, :list => list

    assert thread_ids.uniq.size > 2, "performance must be spread across threads"
  end

  def test_exception_during_multithreading
    list = (1..100).to_a
    list[23] = :blow_up

    assert_raises CustomError do
      @conductor.perform @operation, :list => list
    end
  end
end
