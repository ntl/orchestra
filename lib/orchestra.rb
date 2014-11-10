require_relative "orchestra/version"

module Orchestra
  extend self

  def define_operation &block
    builder = Operation::Builder.new
    Operation::DSL.evaluate builder, &block
    builder.build_operation
  end

  class Conductor
    def initialize services = {}
      @registry = {}
      register_services services
    end

    def perform operation, params = {}
    end

    def register service, &block
      @registry[service] = block
    end

    def register_services services
      services.each do |service, val|
        register Util.to_lazy_thunk val
      end
    end
  end

  module Util
    extend self

    def extract_hash ary
      if ary.last.is_a? Hash
        hsh = ary.pop
      else
        hsh = {}
      end
      [hsh, ary]
    end

    def to_lazy_thunk obj
      if obj.respond_to? :to_proc
        obj
      else
        lambda { obj }
      end
    end
  end

  class Operation
    def perform *;
    end

    class Builder
      def build_operation
        Operation.new
      end
    end

    class DSL < BasicObject
      def self.evaluate builder, &block
        context = new builder
        context.instance_eval &block
      end

      attr_accessor :result

      attr :nodes

      def initialize builder
        @builder = builder
        @nodes = {}
      end

      def node name, &block
        builder = Node::Builder.new
        @nodes[name] = Node::DSL.evaluate builder, &block
        builder.build_node
      end
    end
  end

  class Node
    class Builder
      def build_node
        Node.new
      end
    end

    class DSL < BasicObject
      def self.evaluate builder, &block
        context = new builder
        context.instance_eval &block
      end

      attr :collection, :dependencies, :perform_block, :provisions, :perform

      def initialize builder
        @builder = builder
        @dependencies = []
        @provisions = []
      end

      def depends_on *dependencies
        defaults, dependencies = Util.extract_hash dependencies
        @dependencies.concat dependencies
        defaults.each do |key, default|
          dependencies << key
          defaults[key] = Util.to_lazy_thunk default
        end
      end

      def provides *provisions
        @provisions.concat provisions
      end

      def perform &block
        @perform_block = block
      end

      def iterates_over dependency
        @dependencies << dependency
        @collection = dependency
      end
    end
  end
end
