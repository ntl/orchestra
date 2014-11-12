module TestRunner
  extend self

  def run_in_subprocess
    pid = fork do run end
    _, status = Process.wait2 pid
    status
  end

  def run
    Bundler.require :test
    load 'test/test_helper.rb'
    tests = Dir["test/**/*_test.rb"]
    tests.select! do |test| test == ENV['TEST'] end if ENV['TEST']
    tests.each &method(:load)
    argv = (ENV['TESTOPTS'] || '').split %r{[[:space:]]+}
    exit Minitest.run argv
  end
end
