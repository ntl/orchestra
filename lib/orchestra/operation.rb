module Orchestra
  class Operation < Module
    def self.new *args, &block
      return super unless block_given?
      unless args.empty?
        raise ArgumentError, "wrong number of arguments (#{args.size} for 0)"
      end
      builder = DSL::Operations::Builder.new
      DSL::Operations::Context.evaluate builder, &block
      builder.build_operation
    end

    extend Forwardable

    def_delegators :@default_run_list, :provisions, :dependencies,
      :optional_dependencies, :required_dependencies

    attr :registry, :result, :steps

    def initialize args = {}
      @result, @command, @steps = Util.extract_key_args args,
        :result, :command => false, :steps => {}
      @default_run_list = RunList.build steps, result, []
    end

    def process output
      output.select do |key, _| key = result end
    end

    def start_performance *args
      conductor, input = extract_args args
      run_list = RunList.build steps, result, input.keys
      performance = Performance.new conductor, run_list, input
      yield performance if block_given?
      performance.publish :operation_entered, name, input
      performance
    end

    def perform *args, &block
      performance = start_performance *args, &block
      performance.perform
      output = performance.extract_result result
      performance.publish :operation_exited, name, output
      @command ? nil : output
    end

    def command?
      @command ? true : false
    end

    private

    def extract_args args
      conductor = args.size > 1 ? args.shift : Conductor.new
      input = args.fetch 0 do {} end
      [conductor, input]
    end
  end
end
