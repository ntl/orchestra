require "forwardable"
require "invokr"
require "observer"

module Orchestra
  extend self

  def configure &block
    Configuration.module_eval &block
  end

  def execute operation, inputs = {}
    Conductor.new.execute operation, inputs
  end

  Dir[File.expand_path '../orchestra/**/*.rb', __FILE__].each &method(:load)
end
