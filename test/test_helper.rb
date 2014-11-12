require "minitest/hell"
require "minitest/mock"
require "webmock/minitest"

Dir['test/examples/**/*.rb'].each &method(:load)

WebMock.disable_net_connect!

WebMock::StubRegistry.class_eval do
  undef_method :request_stubs=

  def per_thread_stubs
    @per_thread_stubs ||= Hash.new do |hsh, thread_id| hsh[thread_id] = [] end
  end

  def current_thread_stubs
    per_thread_stubs[Thread.current.object_id]
  end

  def reset!
    current_thread_stubs.clear
  end

  alias_method :request_stubs, :current_thread_stubs
end

WebMock::StubRegistry.instance.reset!

class Minitest::Test
  def before_setup
    Orchestra::Configuration.reset
  end
end
