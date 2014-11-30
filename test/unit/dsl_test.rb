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
      node :convert_to_number do
        depends_on :string
        provides :number
        perform do string.to_i end
      end
      result do
        depends_on :number
        perform do number * 4 end
      end
    end

    assert_equal 44, Orchestra.perform(operation, :string => "11")
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
