module OperationTest
  class PerformTest < Minitest::Test
    def test_simple_operation
      operation = build_simple_operation

      assert_equal(
        %(THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG),
        operation.perform(:sentence => %(the quick brown fox jumps over the lazy dog)),
      )
    end

    def test_performing_operation_without_inputs
      operation = build_simple_operation

      error = assert_raises Orchestra::MissingInputError do
        operation.perform
      end

      assert_equal %(Missing input :sentence), error.message
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
      operation = Orchestra.define do
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
        Orchestra.perform operation, :bar => nil
      end

      assert_equal "Missing inputs :bar and :qux", error.message
    end

    private

    def build_simple_operation
      Orchestra.define do
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
      Orchestra.define do
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

  class IntrospectionTest < Minitest::Test
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

  end

  class EmbeddingOperationsTest < Minitest::Test
    def test_embedding_operations
      inner = Orchestra.define do
        node :double do
          depends_on :number
          provides :doubled
          perform do number * 2 end
        end

        result :plus_one do
          depends_on :doubled
          perform do doubled + 1 end
        end
      end

      outer = Orchestra.define do
        node inner

        result :squared do
          depends_on :plus_one
          perform do plus_one ** 2 end
        end
      end

      telemetry = {}

      conductor = Orchestra::Conductor.new
      conductor.add_observer TelemetryRecorder.new telemetry

      result = conductor.perform outer, :number => 4

      assert_equal 81, result

      assert_equal expected_telemetry, telemetry
    end

    private

    def expected_telemetry
      {
        :input => { :number => 4 },
        :movements => {
          :double => {
            :input  => { :number => 4 },
            :output => { :doubled => 8 },
          },
          :plus_one => {
            :input  => { :doubled => 8 },
            :output => { :plus_one => 9 },
          },
          :squared => {
            :input  => { :plus_one => 9 },
            :output => { :squared => 81 },
          },
        },
        :output => 81,
        :performance_name => nil,
        :service_calls => [],
      }
    end
  end
end
