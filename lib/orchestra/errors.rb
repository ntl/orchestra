module Orchestra
  class Error < StandardError
    def list_out list
      list = list.map &:inspect
      return list.fetch 0 if list.size == 1
      list.fetch 0
      second_to_last, last = list.slice! -2..-1
      str = list.join ', '
      str << ', ' unless str.empty?
      str << "#{second_to_last} and #{last}"
      str
    end
  end

  class MissingProvisionError < Error
    attr_writer :name

    def initialize missing_provisions
      @missing_provisions = missing_provisions
    end

    def name
      @name ||= "<anonymous>"
    end

    def to_s
      "Node `#{name}' failed to supply output: #{list_out @missing_provisions}"
    end
  end

  class CircularDependencyError < Error
    def to_s
      "Circular dependency detected! Check your dependencies/provides"
    end
  end

  class MissingInputError < Error
    def initialize missing_input
      @missing_input = missing_input
    end

    def count
      @missing_input.count
    end

    def to_s
      "Missing input#{'s' unless count == 1} #{list_out @missing_input}"
    end
  end
end
