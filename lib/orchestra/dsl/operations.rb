module Orchestra
  module DSL
    module Operations
      class Builder
        attr_writer :command, :result

        def initialize
          @nodes = {}
        end

        def build_operation
          raise ArgumentError, "Must supply a result" if @result.nil?
          raise ArgumentError, "Must supply at least one node" if @nodes.empty?
          Operation.new(
            :command => @command,
            :nodes   => @nodes,
            :result  => @result,
          )
        end

        def add_node name_or_object, args = {}, &block
          name, node = case name_or_object
          when nil then build_anonymous_node block
          when Operation then build_embedded_operation_node name_or_object
          when ::String, ::Symbol then build_inline_node name_or_object, block
          else build_object_node name_or_object, args
          end
          node.provisions << name.to_sym if node.provisions.empty?
          set_node name.to_sym, node
        end

        def set_node name, node
          if @nodes.has_key? name
            raise ArgumentError, "There are duplicate nodes named #{name.inspect}"
          end
          @nodes[name] = node
          node.freeze
        end

        def build_anonymous_node block
          node = Node::InlineNode.build &block
          unless node.provisions.size == 1
            raise ArgumentError, "Could not infer name for node from a provision"
          end
          name = node.provisions.fetch 0
          [name, node]
        end

        def build_embedded_operation_node operation
          name = object_name operation
          [name, operation]
        end

        def build_inline_node name, block
          node = Node::InlineNode.build &block
          [name, node]
        end

        def build_object_node object, args
          name = object_name object
          node = ObjectAdapter.build_node object, args
          [name, node]
        end

        private

        def object_name object
          object_name = object.name || 'anonymous'
          Util.to_snake_case Util.demodulize object_name
        end
      end

      class Context < BasicObject
        def self.evaluate builder, &block
          context = new builder
          context.instance_eval &block
        end

        attr :nodes

        def initialize builder
          @builder = builder
        end

        def node *args, &block
          @builder.add_node *args, &block
          nil
        end

        def result= result
          @builder.result = result
          nil
        end

        def result name = nil, &block
          node = @builder.add_node name, &block
          name ||= node.provisions.fetch 0
          self.result = name
        end

        def finally name = :__finally__, &block
          @builder.add_node name, &block
          @builder.command = true
          self.result = name
        end
      end
    end
  end
end
