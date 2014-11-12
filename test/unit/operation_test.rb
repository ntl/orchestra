class OperationTest < Minitest::Test
  def test_simple_operation
    operation = build_simple_operation

    assert_equal(
      %(THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG),
      operation.perform(:sentence => %(the quick brown fox jumps over the lazy dog)),
    )
  end

  def test_mutating_inputs
    operation = build_mutator

    shopping_list = [%(1 clove garlic)]
    operation.perform :shopping_list => shopping_list

    assert_equal(
      [%(1 clove garlic), %(2 bunches of carrots), %(1 stalk of celery), %(3 yellow onions)],
      shopping_list,
    )
  end

  def test_skipping_unnecessary_steps
    operation = build_simple_operation

    assert_equal(
      %(THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG),
      operation.perform(:upcased_word_list => %w(THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG)),
    )
  end

  def test_introspecting_dependencies
    node = Orchestra::Node::InlineNode.build do
      depends_on :foo, :bar => :baz
      provides :baz
      perform do :noop end
    end

    assert_equal [:foo, :bar], node.dependencies
  end

  def test_introspecting_optional_dependencies
    node = Orchestra::Node::InlineNode.build do
      depends_on :foo, :bar => :baz
      provides :qux
      perform do :noop end
    end

    assert_equal [:bar], node.optional_dependencies
  end

  def test_introspecting_mandatory_dependencies
    node = Orchestra::Node::InlineNode.build do
      depends_on :foo, :bar => :baz
      provides :baz
      perform do :noop end
    end

    assert_equal [:foo], node.required_dependencies
  end

  def test_passing_conductor_into_nodes
    conductor = Orchestra::Conductor.new

    node = Orchestra::Node::InlineNode.build do
      depends_on :conductor
      provides :conductor_id
      perform do conductor.object_id end
    end

    assert_equal conductor.object_id, node.perform[:conductor_id]
  end

  def test_missing_input_errors
    operation = Orchestra.define_operation do
      node :foo do
        depends_on :bar
        perform do bar + bar end
      end
      node :baz do
        depends_on :qux
        perform do qux * qux end
      end
      node :result do
        depends_on :foo, :baz
        perform do baz - foo end
      end
      self.result = :result
    end

    error = assert_raises Orchestra::MissingInputError do
      Orchestra.perform operation
    end

    assert_equal "Missing inputs :bar and :qux", error.message
  end

  private

  def build_simple_operation
    Orchestra.define_operation do
      node :split do
        depends_on :sentence
        provides :word_list
        perform do sentence.split %r{[[:space:]]+} end
      end

      node :upcase do
        depends_on :word_list
        provides :upcased_word_list
        perform do word_list.map &:upcase end
      end

      node :join do
        depends_on :upcased_word_list
        perform do upcased_word_list.join ' ' end
      end

      self.result = :join
    end
  end

  def build_mutator
    Orchestra.define_operation do
      node :carrots do
        depends_on :shopping_list
        provides :shopping_list
        perform do shopping_list << "2 bunches of carrots" end
      end

      node :celery do
        depends_on :shopping_list
        provides :shopping_list
        perform do shopping_list << "1 stalk of celery" end
      end

      node :onions do
        depends_on :shopping_list
        provides :shopping_list
        perform do shopping_list << "3 yellow onions" end
      end

      self.result = :shopping_list
    end
  end
end
