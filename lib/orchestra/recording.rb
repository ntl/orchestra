module Orchestra
  class Recording
    attr :input, :output, :services

    def initialize
      @services = Hash.new do |hsh, service_name| hsh[service_name] = [] end
    end

    def update event_name, *args
      case event_name
      when :service_accessed then
        service_name, recording = args
        @services[service_name] << recording
      when :performance_started then
        _, @input = args
      when :performance_finished then
        _, @output = args
      else
      end
    end

    def to_h
      {
        :input => input,
        :output => output,
        :service_recordings => services,
      }
    end

    def self.replay operation, input, service_recordings
      replayed_services = {}
      service_recordings.each do |svc, service_recording|
        replayed_services[svc] = Playback.build service_recording
      end
      conductor = Conductor.new replayed_services
      conductor.perform operation, input
    end

    class Playback < BasicObject
      attr :mocks

      def initialize mocks
        @mocks = mocks
      end

      def respond_to? meth
        mocks.has_key? meth
      end

      def self.build service_recording
        factory = Factory.new
        factory.build service_recording
      end

      class Factory
        attr :klass, :mocks

        def initialize
          @klass = Class.new Playback
          @mocks = Hash.new do |hsh, meth| hsh[meth] = {} end
        end

        def build service_recording
          record = method :<<
          service_recording.each &record
          klass.new mocks
        end

        def << record
          method = record[:method].to_sym
          unless klass.instance_methods.include? method
            klass.send :define_method, method do |*args| mocks[method][args] end
          end
          mocks[method][record[:input]] = record[:output]
        end

        def singleton
          singleton = class << instance ; self end
        end
      end
    end
  end
end
