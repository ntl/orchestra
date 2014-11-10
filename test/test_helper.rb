require "minitest/hell"
require "webmock/minitest"

load 'lib/orchestra.rb'

Dir['test/examples/**/*.rb'].each &method(:load)

class Minitest::Test
  parallelize_me!
end
