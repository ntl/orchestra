module Orchestra
  module DSL
    module Steps
      class Builder
        attr_accessor :collection, :execute_block

        attr :defaults, :dependencies, :provisions

        def initialize
          @defaults = {}
          @dependencies = []
          @provisions = []
        end

        def build_step
          Step::InlineStep.new(
            :collection    => collection,
            :defaults      => defaults,
            :dependencies  => dependencies,
            :execute_block => execute_block,
            :provides      => provisions,
          )
        end
      end

      class Context < BasicObject
        def self.evaluate builder, &block
          context = new builder
          context.instance_eval &block
        end

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

        def modifies provision, args = {}
          collection, _ = Util.extract_key_args args, :collection => false
          if collection
            iterates_over provision
          else
            depends_on provision
          end
          provides provision
        end

        def provides *provisions
          @builder.provisions.concat provisions
        end

        def execute &block
          @builder.execute_block = block
        end

        def iterates_over dependency
          @builder.dependencies << dependency
          @builder.collection = dependency
        end
      end
    end
  end
end
