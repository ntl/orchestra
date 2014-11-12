require "rake/testtask"
require "bundler/gem_tasks"

Dir["test/lib/**/*.rb"].each &method(:load)
Dir["test/lib/tasks/**/*.rake"].each &method(:load)

task :env do
  require 'bundler'
  Bundler.setup
  Bundler.require :default, :development
end

desc "Open a development console"
task :console => :env do
  Console.load
  Orchestra.pry
end

task :test => :env do TestRunner.run end

task :default => :test
