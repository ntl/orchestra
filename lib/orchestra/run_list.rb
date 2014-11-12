module Orchestra
  class RunList
    def self.build nodes, result, input_names
      builder = Builder.new result, input_names
      builder.merge! nodes
      builder.build
    end

    include Enumerable

    def initialize nodes
      @nodes = nodes
      @nodes.freeze
      freeze
    end

    def each &block
      return to_enum :each unless block_given?
      @nodes.each &block
    end

    def node_names
      @nodes.keys
    end

    def dependencies
      optional = collect_from_nodes :optional_dependencies
      required = collect_from_nodes :required_dependencies
      (optional + required).uniq
    end

    def optional_dependencies
      collect_from_nodes :optional_dependencies
    end

    def provisions
      collect_from_nodes :provisions
    end

    def required_dependencies
      required_deps = collect_from_nodes :required_dependencies
      required_deps - optional_dependencies - provisions
    end

    private

    def collect_from_nodes method_name
      set = @nodes.each_with_object Set.new do |(_, node), set|
        deps = node.public_send method_name
        deps.each &set.method(:<<)
      end
      set.to_a.tap &:sort!
    end

    class Builder
      attr :input_names, :result

      def initialize result, input_names = []
        @input_names = input_names
        @nodes_hash = {}
        @required = [result]
        @result = result
        freeze
      end

      def merge! nodes
        nodes.each do |name, node|
          self[name] = node
        end
      end

      def []= name, node
        @nodes_hash[name] = node
      end

      def node_names
        @nodes_hash.keys
      end

      def nodes
        @nodes_hash.values
      end

      def build
        sort!
        prune!
        RunList.new @nodes_hash
      end

      def sort!
        sorter = Sorter.new @nodes_hash
        sorter.sort!
      end

      def prune!
        nodes.reverse_each.with_object [] do |node, removed|
          removed.<< remove node and next unless required? node
          require node
        end
      end

      def remove node
        @nodes_hash.reject! do |_, n| n == node end
        node
      end

      def require node
        supplied_by_input = input_names.method :include?
        deps = node.required_dependencies.reject &supplied_by_input
        @required.concat deps
        true
      end

      def required? node
        required = @required.method :include?
        node.provisions.any? &required
      end

      class Sorter
        include TSort

        def initialize nodes_hash
          @nodes = nodes_hash
        end

        def sort!
          build_dependency_tree
          tsort.each do |name|
            @nodes[name] = @nodes.delete name
          end
        rescue TSort::Cyclic
          raise CircularDependencyError.new
        end

        def build_dependency_tree
          @hsh = @nodes.each_with_object Hash.new do |(name, node), hsh|
          hsh[name] = build_dependencies_for node
          end
        end

        def build_dependencies_for node
          node.required_dependencies.each_with_object Set.new do |dep, set|
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
          @nodes.each do |name, node|
            provisions = effective_provisions_for node, dep
            return name if provisions.include? dep
          end
          nil
        end

        def effective_provisions_for node, dep
          node.optional_dependencies | node.provisions
        end
      end
    end
  end
end
