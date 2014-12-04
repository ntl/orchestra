require "forwardable"
require "invokr"
require "observer"
require "securerandom"

module Orchestra
  extend self

  def configure &block
    Configuration.module_eval &block
  end

  def execute operation, inputs = {}
    Conductor.new.execute operation, inputs
  end

  def replay_recording operation, store, input = {}
    store = Util.recursively_symbolize store
    input = input.merge store[:input]
    svc_recordings = store[:service_recordings]
    Recording.replay operation, input, svc_recordings
  end

  load File.expand_path('../orchestra/errors.rb', __FILE__)
end

Dir[File.expand_path '../orchestra/**/*.rb', __FILE__].each do |rb_file|
  load rb_file
end
