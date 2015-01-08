module Orchestra
  # Reader object to expose operations and steps to the outside world
  class Node
    attr :name

    extend Forwardable

    def_delegators :@node, :provisions, :dependencies, :optional_dependencies,
      :required_dependencies

    def initialize step_or_operation, name
      @name = name
      @node = step_or_operation
      freeze
    end

    def to_h
      {
        dependencies: dependencies,
        name: name,
        optional_dependencies: optional_dependencies,
        provisions: provisions,
        required_dependencies: required_dependencies,
      }
    end

    def inspect
      params = to_h.each_with_object [] do |(key, val), list|
        list << "#{key}=#{val.inspect}"
      end
      "#<Orchestra::Node #{params.join ', '}>"
    end

    def operation?
      @node.is_a? Operation
    end

    def step?
      not operation?
    end
  end
end
