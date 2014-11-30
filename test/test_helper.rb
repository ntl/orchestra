require "json"
require "minitest/hell"
require "minitest/mock"
require "stringio"
require "webmock/minitest"

Dir['test/examples/**/*.rb'].each &method(:load)

WebMock.disable_net_connect!

class Minitest::Test
  def before_setup
    Orchestra::Configuration.reset
  end
end
