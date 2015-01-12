module Orchestra
  module Execution
    extend self

    def build operation, conductor, input = {}
      run_list = RunList.build operation.steps, operation.result, input.keys
      node = Recording::Node.new run_list, operation.name, input
      Operation.new conductor, run_list, input, node
    end

    def execute_step step, input
      node = Recording::Node.new step, 'anonymous', input
      operation_execution = Operation.new Conductor.new, {}, input, node
      Step.execute step, node.name, operation_execution
    end

    class Operation
      include Observable
      extend Forwardable

      def_delegators :@run_list, :provisions, :dependencies,
        :optional_dependencies, :required_dependencies

      attr :conductor, :input, :node, :registry, :run_list, :state

      def initialize conductor, run_list, input, node
        @conductor = conductor
        @input = input.dup
        @node = node
        @run_list = run_list
        @registry = conductor.build_registry self
        @state = registry.merge input
      end

      def execute
        publish :operation_entered, node, node.input if node
        ensure_inputs_are_present!
        run_list.each do |name, step| process name, step end
        publish :operation_exited, node, output if node
        output
      rescue => error
        publish :error_raised, error
        raise error
      end

      def output
        state.fetch run_list.result
      end

      def process name, step
        output = Step.execute step, name, self
        state.merge! output
      end

      def ensure_inputs_are_present!
        has_dep = state.method :[]
        missing_input = required_dependencies.reject &has_dep
        raise MissingInputError.new missing_input unless missing_input.empty?
      end

      def publish event, *payload
        changed
        notify_observers event, *payload
      end

      def thread_pool
        conductor.thread_pool
      end
    end

    class Step
      def self.execute step, *args
        instance = new step, *args
        instance.execute
      end

      def self.new step, *args
        if step.is_a? Orchestra::Operation
          klass = EmbeddedOperation
        else
          klass = step.collection ? CollectionStep : self
        end
        instance = klass.allocate
        instance.send :initialize, step, *args
        instance
      end

      attr :context, :name, :node, :operation_execution, :step

      def initialize step, name, operation_execution
        @name = name
        @operation_execution = operation_execution
        @step = step
        @context = build_context
      end

      def execute
        @node = Recording::Node.new step, name, input
        operation_execution.publish :step_entered, node, node.input
        output = step.process invoke
        operation_execution.publish :step_exited, node, output
        output
      end

      def input
        registry = operation_execution.registry
        operation_execution.state.reject do |key, val|
          registry[key] == val or not step.dependencies.include? key
        end
      end

      def invoke
        context.execute
      end

      def build_context
        step.build_context operation_execution.state
      end

      def to_node
        Node.new step, name
      end
    end

    class CollectionStep < Step
      def invoke
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
        operation_execution.thread_pool.enqueue do
          result = context.execute element
          yield [result, index]
        end
      end

      def prepare_collection
        batch = context.fetch_collection
        output = [nil] * batch.size
        [batch, output]
      end
    end

    class EmbeddedOperation < Step
      def invoke
        super
        context.state.select do |k,_| k == step.result end
      end

      def build_context
        conductor = operation_execution.registry[:conductor]
        copy_observers = conductor.method :copy_observers
        step.start_execution conductor, input, &copy_observers
      end

      def input
        operation_execution.state
      end
    end
  end
end
