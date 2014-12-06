module Orchestra
  module DSL
    module Operations
      class Builder
        attr_writer :command, :result

        def initialize
          @steps = {}
        end

        def build_operation
          raise ArgumentError, "Must supply a result" if @result.nil?
          raise ArgumentError, "Must supply at least one step" if @steps.empty?
          Operation.new(
            :command => @command,
            :steps   => @steps,
            :result  => @result,
          )
        end

        def add_step name_or_object, args = {}, &block
          name, step = case name_or_object
          when nil then build_anonymous_step block
          when Operation then build_embedded_operation_step name_or_object
          when ::String, ::Symbol then build_inline_step name_or_object, block
          else build_object_step name_or_object, args
          end
          step.provisions << name.to_sym if step.provisions.empty?
          set_step name.to_sym, step
        end

        def set_step name, step
          if @steps.has_key? name
            raise ArgumentError, "There are duplicate steps named #{name.inspect}"
          end
          @steps[name] = step
          step.freeze
        end

        def build_anonymous_step block
          step = Step::InlineStep.build &block
          unless step.provisions.size == 1
            raise ArgumentError, "Could not infer name for step from a provision"
          end
          name = step.provisions.fetch 0
          [name, step]
        end

        def build_embedded_operation_step operation
          name = object_name operation
          [name || operation.result, operation]
        end

        def build_inline_step name, block
          step = Step::InlineStep.build &block
          [name, step]
        end

        def build_object_step object, args
          name = object_name object
          step = ObjectAdapter.build_step object, args
          [name, step]
        end

        private

        def object_name object
          object.name and Util.to_snake_case Util.demodulize object.name
        end
      end

      class Context < BasicObject
        def self.evaluate builder, &block
          context = new builder
          context.instance_eval &block
        end

        attr :steps

        def initialize builder
          @builder = builder
        end

        def step *args, &block
          @builder.add_step *args, &block
          nil
        end

        def result= result
          @builder.result = result
          nil
        end

        def result name = nil, &block
          step = @builder.add_step name, &block
          name ||= step.provisions.fetch 0
          self.result = name
        end

        def finally name = :__finally__, &block
          @builder.add_step name, &block
          @builder.command = true
          self.result = name
        end
      end
    end
  end
end
