require "forwardable"
require "invokr"
require "observer"
require "securerandom"

require_relative "orchestra/version"

module Orchestra
  extend self

  autoload :Conductor, "orchestra/conductor"
  autoload :Configuration, "orchestra/configuration"
  autoload :Node, "orchestra/node"
  autoload :Operation, "orchestra/operation"
  autoload :Performance, "orchestra/performance"
  autoload :Recording, "orchestra/recording"
  autoload :RunList, "orchestra/run_list"
  autoload :ThreadPool, "orchestra/thread_pool"
  autoload :Util, "orchestra/util"

  module DSL
    autoload :Nodes, "orchestra/dsl/nodes"
    autoload :ObjectAdapter, "orchestra/dsl/object_adapter"
    autoload :Operations, "orchestra/dsl/operations"
  end

  def configure &block
    Configuration.module_eval &block
  end

  def define_operation &block
    builder = DSL::Operations::Builder.new
    DSL::Operations::Context.evaluate builder, &block
    builder.build_operation
  end

  def perform operation, inputs = {}
    Conductor.new.perform operation, inputs
  end

  def replay_recording operation, store, input = {}
    input = input.merge store[:input] || store['input']
    svc_recordings = store[:service_recordings] || store['service_recordings']
    Recording.replay operation, input, svc_recordings
  end

  load File.expand_path('../orchestra/errors.rb', __FILE__)
end
