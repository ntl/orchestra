module Orchestra
  module DSL
    module Operations
      class Builder
        attr_writer :result

        def initialize
          @nodes = {}
        end

        def build_operation
          Operation.new(
            :nodes => @nodes,
            :result => @result,
          )
        end

        def add_node name_or_object, args = {}, &block
          case name_or_object
          when ::String, ::Symbol then
            name = name_or_object
            node = Node::InlineNode.build &block
          else
            name = Util.to_snake_case Util.demodulize name_or_object.name
            node = ObjectAdapter.build_node name_or_object, args
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

        def result args = {}, &block
          @builder.add_node :result, &block
          self.result = :result
        end
      end
    end
  end
end
