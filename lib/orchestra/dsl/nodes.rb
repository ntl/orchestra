module Orchestra
  module DSL
    module Nodes
      class Builder
        attr_accessor :collection, :perform_block

        attr :defaults, :dependencies, :provisions

        def initialize
          @defaults = {}
          @dependencies = []
          @provisions = []
        end

        def build_node
          Node::InlineNode.new(
            :collection    => collection,
            :defaults      => defaults,
            :dependencies  => dependencies,
            :perform_block => perform_block,
            :provides      => provisions,
          )
        end
      end

      class Context < BasicObject
        def self.evaluate builder, &block
          context = new builder
          context.instance_eval &block
        end

        attr :collection, :perform

        def initialize builder
          @builder = builder
        end

        def depends_on *dependencies
          defaults, dependencies = Util.extract_hash dependencies
          @builder.dependencies.concat dependencies
          defaults.each do |key, default|
            @builder.dependencies << key
            @builder.defaults[key] = Util.to_lazy_thunk default
          end
        end

        def modifies *provisions
          depends_on *provisions
          provides *provisions
        end

        def provides *provisions
          @builder.provisions.concat provisions
        end

        def perform &block
          @builder.perform_block = block
        end

        def iterates_over dependency
          @builder.dependencies << dependency
          @builder.collection = dependency
        end
      end
    end
  end
end
