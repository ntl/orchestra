module Orchestra
  class Performance
    include Observable
    extend Forwardable

    def_delegators :@run_list, :provisions, :dependencies,
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
      run_list.each do |name, step| process name, step end
    rescue => error
      publish :error_raised, error
      raise error
    end

    def process name, step
      input = input_for step
      publish :step_entered, name, input
      output = perform_step step
      publish :step_exited, name, output
      state.merge! output
    end

    def perform_step step
      Movement.perform step, self
    end

    def ensure_inputs_are_present!
      has_dep = state.method :[]
      missing_input = required_dependencies.reject &has_dep
      raise MissingInputError.new missing_input unless missing_input.empty?
    end

    def input_for step
      state.reject do |key, val|
        registry[key] == val or not step.dependencies.include? key
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
      def self.perform step, *args
        if step.is_a? Operation
          klass = EmbeddedOperation
        else
          klass = step.collection ? CollectionMovement : self
        end
        instance = klass.new step, *args
        step.process instance.perform
      end

      attr :context, :step, :performance

      def initialize step, performance
        @step = step
        @performance = performance
        @context = build_context performance
      end

      def perform
        context.perform
      end

      def build_context performance
        step.build_context performance.state
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
        context.state.select do |k,_| k == step.result end
      end

      def build_context performance
        conductor = performance.registry[:conductor]
        copy_observers = conductor.method :copy_observers
        step.start_performance conductor, input, &copy_observers
      end

      def input
        performance.state
      end
    end
  end
end
