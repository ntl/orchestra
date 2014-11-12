module Orchestra
  class Operation < Module
    attr :registry, :result, :nodes

    def initialize args = {}
      @result, @nodes = Util.extract_key_args args, :result, :nodes => {}
    end

    def start_performance *args
      conductor, input = extract_args args
      run_list = RunList.build nodes, result, input.keys
      performance = Performance.new conductor, run_list, input
      yield performance if block_given?
      performance.publish :performance_started, name, input
      performance
    end

    def perform *args, &block
      performance = start_performance *args, &block
      performance.perform
      output = performance.fetch result
      performance.publish :performance_finished, name, output
      output
    end

    private

    def extract_args args
      conductor = args.size == 1 ? Conductor.new : args.shift
      input = args.last
      [conductor, input]
    end
  end
end
