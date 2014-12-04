class DSLTest < Minitest::Test
  def test_failing_to_supply_perform_block
    error = assert_raises ArgumentError do
      Orchestra::Step::InlineStep.build do
        provides :foo
        depends_on :bar
      end
    end

    assert_equal "expected inline step to define a perform block", error.message
  end

  def test_two_steps_one_name
    error = assert_raises ArgumentError do
      Orchestra::Operation.new do
        step :foo do
          depends_on :bar
          perform do bar + bar end
        end
        step :foo do
          depends_on :qux
          perform do qux * qux end
        end
      end
    end

    assert_equal "There are duplicate steps named :foo", error.message
  end

  def test_result_step
    operation = Orchestra::Operation.new do
      result :foo do perform do 'foo' end end
    end
    assert_equal :foo, operation.result

    error = assert_raises ArgumentError do
      operation = Orchestra::Operation.new do
        result do perform do 'foo' end end
      end
    end
    assert_equal "Could not infer name for step from a provision", error.message

    operation = Orchestra::Operation.new do
      result do
        provides :foo
        perform do 'foo' end
      end
    end
    assert_equal :foo, operation.result
  end

  def test_command_operations_using_finally
    operation = Orchestra::Operation.new do
      step :unnecessary do
        provides :baz
        perform do raise "Can't get here" end
      end

      step :necessary do
        depends_on :baz
        provides :bar
        perform do baz + 1 end
      end

      finally do
        depends_on :bar
        perform do bar * 2 end
      end
    end

    test_observer = Module.new do
      extend self
      attr :result
      def update event, *args
        return unless event == :operation_exited
        _, @result = args
      end
    end

    conductor = Orchestra::Conductor.new
    conductor.add_observer test_observer

    assert_equal nil, conductor.perform(operation, :baz => 3)
    assert_equal 8,   test_observer.result
  end

  def test_modifies
    operation = Orchestra::Operation.new do
      result do
        modifies :list
        perform do list << :foo end
      end
    end

    ary = []
    Orchestra.perform operation, :list => ary

    assert_equal [:foo], ary
  end

  def test_must_supply_result
    error = assert_raises ArgumentError do
      Orchestra::Operation.new do
        step :foo do
          perform do 'foo' end
        end
      end
    end

    assert_equal "Must supply a result", error.message
  end

  def test_must_contain_at_least_one_step
    error = assert_raises ArgumentError do
      Orchestra::Operation.new do
        self.result = :foo
      end
    end

    assert_equal "Must supply at least one step", error.message
  end
end
