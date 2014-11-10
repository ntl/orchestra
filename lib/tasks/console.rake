module Console
  extend self

  def load
    ENV['N'] ||= '4'
    Bundler.require "debugger_#{RUBY_ENGINE}"
    Bundler.require :development
    define_reload
    define_rake
    clean_backtraces
  end

  def define_reload
    Pry::Commands.block_command "reload!", "Reload gem code" do
      puts "Reloading..."
      Truck.reset!
      _pry_.binding_stack.push Prompt.__binding__
      _pry_.binding_stack.shift
    end
  end

  def define_rake
    Pry::Commands.create_command %r{(?:bin/)?rake}, keep_retval: true do
      description "Run the test suite"

      def process
        run "reload!"

        status = TestRunner.run

        build_passed = status.exitstatus == 0
        operator = args.shift
        run_system_command(build_passed, operator, args) if operator
        build_passed
      end

      def run_system_command build_passed, operator, system_args
        if operator == '&&'
          system *system_args if build_passed
        elsif operator == '||' && !build_passed
          system *system_args unless build_passed
        else
          raise ArgumentError, "Must supply either '&&' or '||' operators, followed by a shell command"
        end
      end
    end
  end

  def clean_backtraces
    Exception.class_eval do
      def render_with_filtering *args
        io = args[1] || STDERR
        args[1] = BacktraceFilter.new(io)
        render_without_filtering *args
      end
      alias_method :render_without_filtering, :render
      alias_method :render, :render_with_filtering

    end
  end

  class BacktraceFilter
    def initialize io
      @io = io
    end

    def puts message = "\n"
      dont_filter_yet = true
      message.each_line do |line|
        if line.match %r{ at }
          next unless dont_filter_yet or line.match %r{(?:lib/orchestra|test)}i
          dont_filter_yet = false
        end
        @io.puts line
      end
    end
  end
end

module TestRunner
  extend self

  def run
    pid = fork do __run end
    _, status = Process.wait2 pid
    status
  end

  def __run
    Bundler.require :test
    load 'test/test_helper.rb'
    Dir["test/**/*_test.rb"].each &method(:load)
    exit Minitest.run
  end
end

desc "Open a development console"
task :console => :env do
  Console.load
  Truck.define_context :Prompt, root: Dir.pwd, autoload_paths: %w(lib)
  Truck.boot!
  Prompt.pry
end
