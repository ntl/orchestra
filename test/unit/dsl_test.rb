class DSLTest < Minitest::Test
  def test_failing_to_supply_execute_block
    error = assert_raises ArgumentError do
      Orchestra::Step::InlineStep.build do
        provides :foo
        depends_on :bar
      end
    end

    assert_equal "expected inline step to define a execute block", error.message
  end

  def test_two_steps_one_name
    error = assert_raises ArgumentError do
      Orchestra::Operation.new do
        step :foo do
          depends_on :bar
          execute do bar + bar end
        end
        step :foo do
          depends_on :qux
          execute do qux * qux end
        end
      end
    end

    assert_equal "There are duplicate steps named :foo", error.message
  end

  def test_result_step
    operation = Orchestra::Operation.new do
      result :foo do execute do 'foo' end end
    end
    assert_equal :foo, operation.result

    error = assert_raises ArgumentError do
      operation = Orchestra::Operation.new do
        result do execute do 'foo' end end
      end
    end
    assert_equal "Could not infer name for step from a provision", error.message

    operation = Orchestra::Operation.new do
      result do
        provides :foo
        execute do 'foo' end
      end
    end
    assert_equal :foo, operation.result
  end

  def test_command_operations_using_finally
    operation = Orchestra::Operation.new do
      step :unnecessary do
        provides :baz
        execute do raise "Can't get here" end
      end

      step :necessary do
        depends_on :baz
        provides :bar
        execute do baz + 1 end
      end

      finally do
        depends_on :bar
        execute do bar * 2 end
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

    assert_equal nil, conductor.execute(operation, :baz => 3)
    assert_equal 8,   test_observer.result
  end

  def test_modifies
    operation = Orchestra::Operation.new do
      result do
        modifies :list
        execute do list << :foo end
      end
    end

    ary = []
    Orchestra.execute operation, :list => ary

    assert_equal [:foo], ary
  end

  def test_must_supply_result
    error = assert_raises ArgumentError do
      Orchestra::Operation.new do
        step :foo do
          execute do 'foo' end
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

  def test_cannot_accidentally_try_to_define_a_conductor_with_dsl
    error = assert_raises ArgumentError do
      Orchestra::Conductor.new do
        self.result = :foo
      end
    end

    assert_equal "Supplied block to Conductor.new; did you mean to invoke Orchestra::Operation.new do … end?", error.message
  end
end
