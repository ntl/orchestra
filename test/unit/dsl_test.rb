class DSLTest < Minitest::Test
  def test_failing_to_supply_perform_block
    error = assert_raises ArgumentError do
      Orchestra::Node::InlineNode.build do
        provides :foo
        depends_on :bar
      end
    end

    assert_equal "expected inline node to define a perform block", error.message
  end

  def test_two_nodes_one_name
    error = assert_raises ArgumentError do
      Orchestra.define_operation do
        node :foo do
          depends_on :bar
          perform do bar + bar end
        end
        node :foo do
          depends_on :qux
          perform do qux * qux end
        end
      end
    end

    assert_equal "There are duplicate nodes named :foo", error.message
  end

  def test_result_node
    operation = Orchestra.define_operation do
      result :foo do perform do 'foo' end end
    end
    assert_equal :foo, operation.result

    error = assert_raises ArgumentError do
      operation = Orchestra.define_operation do
        result do perform do 'foo' end end
      end
    end
    assert_equal "Could not infer name for node from a provision", error.message

    operation = Orchestra.define_operation do
      result do
        provides :foo
        perform do 'foo' end
      end
    end
    assert_equal :foo, operation.result
  end

  def test_command_operations_using_finally
    operation = Orchestra.define_operation do
      node :unnecessary do
        provides :baz
        perform do raise "Can't get here" end
      end

      node :necessary do
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
        return unless event == :performance_finished
        _, @result = args
      end
    end

    conductor = Orchestra::Conductor.new
    conductor.add_observer test_observer

    assert_equal nil, conductor.perform(operation, :baz => 3)
    assert_equal 8,   test_observer.result
  end

  def test_modifies
    operation = Orchestra.define_operation do
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
      Orchestra.define_operation do
        node :foo do
          perform do 'foo' end
        end
      end
    end

    assert_equal "Must supply a result", error.message
  end

  def test_must_contain_at_least_one_node
    error = assert_raises ArgumentError do
      Orchestra.define_operation do
        self.result = :foo
      end
    end

    assert_equal "Must supply at least one node", error.message
  end
end
