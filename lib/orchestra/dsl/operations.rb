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

        def build_embedded_operation_step operation
          name = object_name operation
          [name || operation.result, operation]
        end

        def build_inline_step name, block
          step = Step::InlineStep.build &block
          [name, step]
        end

        def build_object_step object, args
          step = ObjectAdapter.build_step object, args
          name = object_name step.adapter
          [name, step]
        end

        private

        def object_name object
          object.name and Util.to_snake_case object.name
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

        def result *args, &block
          args << :result if args.empty?
          step = @builder.add_step *args, &block
          name ||= step.provisions.fetch 0
          self.result = name
        end

        def finally name = :__finally__, &block
          step = @builder.add_step name, &block
          @builder.command = true
          resolved_name = step.provisions.fetch 0
          self.result = resolved_name
        end
      end
    end
  end
end
