module Orchestra
  class Node
    autoload :Output, "orchestra/node/output"

    attr :collection, :dependencies, :provisions

    def initialize args = {}
      @provisions,
      @collection,
      @dependencies = Util.extract_key_args(
        args,
        :provides      => [],
        :collection    => nil,
        :dependencies  => [],
      )
    end

    def required_dependencies
      dependencies - optional_dependencies
    end

    def optional_dependencies
      defaults.keys
    end

    def collection?
      collection ? true : false
    end

    def perform input = {}
      performance = Performance.new Conductor.new, {}, input
      Performance::Movement.perform self, performance
    end

    def process raw_output
      Output.process self, raw_output
    end

    class DelegateNode < Node
      attr :adapter

      def initialize adapter, args = {}
        @adapter = adapter
        super args
      end

      def build_context input
        adapter.build_context input
      end

      def optional_dependencies
        adapter.object_method.optional_dependencies
      end
    end

    class InlineNode < Node
      def self.build &block
        builder = DSL::Nodes::Builder.new
        DSL::Nodes::Context.evaluate builder, &block
        builder.build_node
      end

      attr :context_class, :defaults, :perform_block

      def initialize args = {}
        @defaults = args.delete :defaults do {} end
        @perform_block = args.fetch :perform_block
        args.delete :perform_block
        super args
        @context_class = build_execution_context_class
        validate!
      end

      def validate!
        unless perform_block
          raise ArgumentError, "expected inline node to define a perform block"
        end
      end

      def build_execution_context_class
        context = Class.new ExecutionContext
        context.class_exec dependencies, collection do |deps, collection|
          deps.each do |dep| define_dependency dep end
          alias_method :fetch_collection, collection if collection
        end
        context
      end

      def build_context input
        state = apply_defaults input
        execution_context = context_class.new state, perform_block
      end

      def apply_defaults input
        defaults.each do |key, thunk|
          next if input.has_key? key
          input[key] = thunk.call
        end
        input
      end

      def optional_dependencies
        defaults.keys
      end

      class ExecutionContext
        def self.define_dependency dep
          define_method dep do
            ivar = "@#{dep}"
            return instance_variable_get ivar if instance_variable_defined? ivar
            instance_variable_set ivar, @__state__[dep]
          end
        end

        def initialize state, perform_block
          @__perform_block__ = perform_block
          @__state__ = state
        end

        def perform item = nil
          if @__perform_block__.arity == 0
            instance_exec &@__perform_block__
          else
            instance_exec item, &@__perform_block__
          end
        end
      end
    end
  end
end
