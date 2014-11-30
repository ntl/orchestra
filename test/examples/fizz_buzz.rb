module Examples
  FizzBuzz = Orchestra.define_operation do
    node :make_array do
      depends_on :up_to
      provides :array
      perform do
        up_to.times.to_a
      end
    end

    node :apply_fizzbuzz do
      iterates_over :array
      provides :fizzbuzz
      perform do |num|
        next if num == 0 # filter 0 from the output
        str = ''
        str << "Fizz" if num % 3 == 0
        str << "Buzz" if num % 5 == 0
        str << num.to_s if str.empty?
        str
      end
    end

    finally :print do
      depends_on :io
      iterates_over :fizzbuzz
      perform do |str|
        io.puts str
      end
    end
  end
end
