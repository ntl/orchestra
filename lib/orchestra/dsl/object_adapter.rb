module Orchestra
  module DSL
    class ObjectAdapter
      def self.build_step object, args = {}
        method_name = args.delete :method do :perform end
        collection = args.delete :iterates_over
        adapter_type = determine_type object, method_name
        adapter = adapter_type.new object, method_name, collection
        StepFactory.build adapter, args
      end

      def self.determine_type object, method_name
        if object.public_methods.include? method_name
          SingletonAdapter
        elsif object.kind_of? Class
          ClassAdapter
        else
          SingletonAdapter
        end
      end

      attr :collection, :object, :method_name

      def initialize object, method_name, collection
        @collection = collection
        @method_name = method_name || :perform
        @object = object
      end

      def build_context state
        ObjectContext.new self, state
      end

      def collection?
        @collection ? true : false
      end

      def context_class
        @context_class ||= Step.build_execution_context_class dependencies
      end

      def dependencies
        [collection, *object_method.dependencies].compact
      end
    end

    class SingletonAdapter < ObjectAdapter
      def validate!
        unless object.methods.include? method_name
          raise NotImplementedError,
            "#{object} does not implement method `#{method_name}'"
        end
        if collection?
          raise ArgumentError,
            "#{object} is a singleton; cannot iterate over collection #{collection.inspect}"
        end
      end

      def perform state
        deps = object_method.dependencies
        input = state.select do |key, _| deps.include? key end
        Invokr.invoke :method => method_name, :on => object, :with => input
      end

      def object_method
        Invokr.query_method object.method method_name
      end
    end

    class ClassAdapter < ObjectAdapter
      def validate!
        return if object.instance_methods.include? method_name
        raise NotImplementedError,
          "#{object} does not implement instance method `#{method_name}'"
      end

      def perform state, maybe_item = nil
        instance = Invokr.inject object, :using => state
        args = [method_name]
        args << maybe_item if collection?
        instance.public_send *args
      end

      def object_method
        Invokr.query_method object.instance_method :initialize
      end
    end

    class StepFactory
      def self.build *args
        instance = new *args
        instance.build_step
      end

      attr :adapter, :compact, :provides, :thread_count

      def initialize adapter, args = {}
        @adapter = adapter
        @provides, @compact, @thread_count = Util.extract_key_args args,
          :provides => nil, :compact => false, :thread_count => nil
      end

      def build_step
        adapter.validate!
        Step::ObjectStep.new adapter, build_step_args
      end

      def build_step_args
        hsh = {
          :dependencies => adapter.dependencies,
          :provides     => Array(provides),
        }
        hsh[:collection] = adapter.collection if adapter.collection?
        hsh
      end
    end

    class ObjectContext
      def initialize adapter, state
        @__adapter__ = adapter
        @__state__ = state
        return unless adapter.collection?
        self.singleton_class.send :define_method, :fetch_collection do
          @__state__.fetch adapter.collection
        end
      end

      def perform *args
        @__adapter__.perform @__state__, *args
      end
    end

  end
end
