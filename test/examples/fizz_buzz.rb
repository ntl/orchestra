module Examples
  FizzBuzz = Orchestra::Operation.new do
    step :make_array do
      depends_on :up_to
      provides :array
      execute do
        up_to.times.to_a
      end
    end

    step :apply_fizzbuzz do
      iterates_over :array
      provides :fizzbuzz
      execute do |num|
        next if num == 0 # filter 0 from the output
        str = ''
        str << "Fizz" if num % 3 == 0
        str << "Buzz" if num % 5 == 0
        str << num.to_s if str.empty?
        str
      end
    end

    finally do
      depends_on :stdout
      iterates_over :fizzbuzz
      execute do |str|
        stdout.puts str
      end
    end
  end

  InteractiveFizzBuzz = Orchestra::Operation.new do
    step :prompt_user do
      depends_on :stdin, :stdout
      provides :up_to
      execute do
        stdout.puts "How high would you like to go?"
        stdout.print " => "
        stdout.flush
        value = stdin.gets
        value.to_i
      end
    end

    finally Examples::FizzBuzz
  end
end
