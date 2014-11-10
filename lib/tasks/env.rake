desc "Support task that boots a test environment"
task :env do
  require 'bundler'
  Bundler.setup
  Bundler.require :default
end
