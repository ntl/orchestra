module Orchestra
  class Performance
    include Observable
    extend Forwardable

    def_delegators :@run_list, :node_names, :provisions, :dependencies,
      :optional_dependencies, :required_dependencies

    attr :conductor, :input, :state, :registry, :run_list

    def initialize conductor, run_list, input
      @conductor = conductor
      @input = input.dup
      @run_list = run_list
      @registry = conductor.build_registry self
      @state = registry.merge input
    end

    def perform
      ensure_inputs_are_present!
      run_list.each do |name, node| process name, node end
    rescue => error
      publish :error_raised, error
      raise error
    end

    def process name, node
      input = input_for node
      publish :node_entered, name, input
      output = perform_node node
      publish :node_exited, name, output
      state.merge! output
    end

    def perform_node node
      Movement.perform node, self
    end

    def ensure_inputs_are_present!
      has_dep = state.method :[]
      missing_input = required_dependencies.reject &has_dep
      raise MissingInputError.new missing_input unless missing_input.empty?
    end

    def input_for node
      state.reject do |key, val|
        registry[key] == val or not node.dependencies.include? key
      end
    end

    def extract_result result
      state.fetch result
    end

    def publish event, *payload
      changed
      notify_observers event, *payload
    end

    def thread_pool
      conductor.thread_pool
    end

    class Movement
      def self.perform node, *args
        if node.is_a? Operation
          klass = EmbeddedOperation
        else
          klass = node.collection ? CollectionMovement : self
        end
        instance = klass.new node, *args
        node.process instance.perform
      end

      attr :context, :node, :performance

      def initialize node, performance
        @node = node
        @performance = performance
        @context = build_context performance
      end

      def perform
        context.perform
      end

      def build_context performance
        node.build_context performance.state
      end
    end

    class CollectionMovement < Movement
      def perform
        batch, output = prepare_collection
        jobs = enqueue_jobs batch do |result, index| output[index] = result end
        jobs.each &:wait
        output
      end

      def enqueue_jobs batch, &block
        batch.map.with_index do |element, index|
          enqueue_job element, index, &block
        end
      end

      def enqueue_job element, index
        performance.thread_pool.enqueue do
          result = context.perform element
          yield [result, index]
        end
      end

      def prepare_collection
        batch = context.fetch_collection
        output = [nil] * batch.size
        [batch, output]
      end
    end

    class EmbeddedOperation < Movement
      def perform
        super
        context.state.select do |k,_| k == node.result end
      end

      def build_context performance
        conductor = performance.registry[:conductor]
        performance.publish :operation_entered, node
        copy_observers = conductor.method :copy_observers
        embedded = node.start_performance conductor, input, &copy_observers
        performance.publish :operation_exited, node
        embedded
      end

      def input
        performance.state
      end
    end
  end
end
