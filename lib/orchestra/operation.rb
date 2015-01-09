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

    def execute *args, &block
      execution = start_execution *args, &block
      output = execution.execute
      @command ? nil : output
    end

    def start_execution *args
      conductor, input = extract_args args
      execution = Execution.build self, conductor, input
      yield execution if block_given?
      execution
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
