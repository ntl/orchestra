module Orchestra
  class Conductor
    attr :observers, :services, :thread_pool

    def initialize services = {}
      @services = services
      @thread_pool = ThreadPool.new
      @observers = Set.new
      self.thread_count = Configuration.thread_count
    end

    def execute operation, input = {}
      operation.execute self, input do |execution|
        copy_observers execution
        yield execution if block_given?
      end
    end

    def record *args
      recording = Recording.fresh
      add_observer recording
      execute *args do |execution|
        execution.add_observer recording
      end
      recording
    ensure
      delete_observer recording
    end

    def add_observer observer
      observers << observer
    end

    def delete_observer observer
      observers.delete observer
    end

    def copy_observers observable
      add_observer = observable.method :add_observer
      observers.each &add_observer
    end

    def build_registry observable
      hsh = { :conductor => self }
      services.each_with_object hsh do |(service_name, _), hsh|
        service = resolve_service observable, service_name
        hsh[service_name] = service if service
      end
    end

    def resolve_service observable, service_name
      return nil unless services.has_key? service_name
      service = Util.to_lazy_thunk services[service_name]
      recording = ServiceRecorder.new observable, service_name
      recording.wrap service.call self
    end

    def thread_count
      @thread_pool.count
    end

    def thread_count= new_count
      @thread_pool.count = new_count
    end

    class ServiceRecorder
      attr :observable, :service_name

      def initialize observable, service_name
        @observable = observable
        @service_name = service_name
        @record = []
      end

      def << record
        observable.changed
        observable.notify_observers :service_accessed, service_name, record
        @record << record
      end

      def each &block
        @record.each &block
      end

      def wrap raw_service
        Wrapper.new raw_service, self
      end

      class Wrapper < Delegator
        attr_accessor :service
        alias_method :__getobj__, :service
        alias_method :__setobj__, :service=

          def initialize service, recording
            super service
            @recording = recording
          end

        def kind_of? klass
          super or service.kind_of? klass
        end

        def method_missing meth, *args
          super.tap do |result|
            @recording << {
              :method => meth.to_s,
              :input  => args,
              :output => result,
            }
          end
        end

        def inspect
          "#<#{self.class.name} service=#{service.inspect}>"
        end
      end
    end
  end
end
