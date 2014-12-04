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
      when :operation_entered then
        _, @input = args
      when :operation_exited then
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

    def to_json generator
      generator.generate to_h
    end

    def self.replay operation, input, service_recordings
      replayed_services = {}
      service_recordings.each do |svc, service_recording|
        replayed_services[svc] = Playback.build service_recording
      end
      invoker = Invoker.new replayed_services
      invoker.invoke operation, input
    end
  end
end
