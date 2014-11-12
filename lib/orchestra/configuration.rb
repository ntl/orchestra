module Orchestra
  module Configuration
    extend self

    attr_accessor :thread_count

    def reset
      self.thread_count = 1
    end
    reset
  end
end
