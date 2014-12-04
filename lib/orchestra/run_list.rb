module Orchestra
  class RunList
    def self.build steps, result, input_names
      builder = Builder.new result, input_names
      builder.merge! steps
      builder.build
    end

    include Enumerable

    def initialize steps
      @steps = steps
      @steps.freeze
      freeze
    end

    def each &block
      return to_enum :each unless block_given?
      @steps.each &block
    end

    def step_names
      @steps.keys
    end

    def dependencies
      optional = collect_from_steps :optional_dependencies
      required = collect_from_steps :required_dependencies
      (optional + required).uniq
    end

    def optional_dependencies
      collect_from_steps :optional_dependencies
    end

    def provisions
      collect_from_steps :provisions
    end

    def required_dependencies
      required_deps = collect_from_steps :required_dependencies
      required_deps - optional_dependencies - provisions
    end

    private

    def collect_from_steps method_name
      set = @steps.each_with_object Set.new do |(_, step), set|
        deps = step.public_send method_name
        deps.each &set.method(:<<)
      end
      set.to_a.tap &:sort!
    end

    class Builder
      attr :input_names, :result

      def initialize result, input_names = []
        @input_names = input_names
        @steps_hash = {}
        @required = [result]
        @result = result
        freeze
      end

      def merge! steps
        steps.each do |name, step|
          self[name] = step
        end
      end

      def []= name, step
        @steps_hash[name] = step
      end

      def step_names
        @steps_hash.keys
      end

      def steps
        @steps_hash.values
      end

      def build
        sort!
        prune!
        RunList.new @steps_hash
      end

      def sort!
        sorter = Sorter.new @steps_hash
        sorter.sort!
      end

      def prune!
        steps.reverse_each.with_object [] do |step, removed|
          removed.<< remove step and next unless required? step
          require step
        end
      end

      def remove step
        @steps_hash.reject! do |_, n| n == step end
        step
      end

      def require step
        supplied_by_input = input_names.method :include?
        deps = step.required_dependencies.reject &supplied_by_input
        @required.concat deps
        true
      end

      def required? step
        required = @required.method :include?
        step.provisions.any? &required
      end

      class Sorter
        include TSort

        def initialize steps_hash
          @steps = steps_hash
        end

        def sort!
          build_dependency_tree
          tsort.each do |name|
            @steps[name] = @steps.delete name
          end
        rescue TSort::Cyclic
          raise CircularDependencyError.new
        end

        def build_dependency_tree
          @hsh = @steps.each_with_object Hash.new do |(name, step), hsh|
          hsh[name] = build_dependencies_for step
          end
        end

        def build_dependencies_for step
          step.required_dependencies.each_with_object Set.new do |dep, set|
            provider = provider_for dep
            set << provider if provider
          end
        end

        def tsort_each_node(&block)
          @hsh.each_key &block
        end

        def tsort_each_child(name, &block)
          deps = @hsh.fetch name
          deps.each &block
        end

        def provider_for dep
          @steps.each do |name, step|
            provisions = effective_provisions_for step, dep
            return name if provisions.include? dep
          end
          nil
        end

        def effective_provisions_for step, dep
          step.optional_dependencies | step.provisions
        end
      end
    end
  end
end
