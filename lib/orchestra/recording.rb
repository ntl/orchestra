module Orchestra
  class Recording
    def self.fresh
      services = Hash.new do |hsh, service_name| hsh[service_name] = [] end
      new services
    end

    attr_accessor :input, :output
    attr :services

    def initialize services
      @services = services
    end

    def update event_name, *args
      case event_name
      when :service_accessed then
        service_name, recording = args
        @services[service_name] << recording
      when :operation_entered then
        _, @input = args
      when :operation_exited then
        _, @output = args
      else
      end
    end

    def [] attr
      to_h[attr]
    end

    def to_h
      {
        :input              => input,
        :output             => output,
        :service_recordings => services,
      }
    end

    def to_json generator
      generator.generate to_h
    end

    def replay operation, override_input = {}
      replayed_services = {}
      services.each do |svc, service_recording|
        replayed_services[svc] = Playback.build service_recording
      end
      conductor = Conductor.new replayed_services
      conductor.execute operation, input.merge(override_input)
    end
  end

  def Recording serialized_recording
    recording = Recording.new serialized_recording[:service_recordings]
    recording.input = serialized_recording[:input]
    recording.output = serialized_recording[:output]
    recording.freeze
  end
end
