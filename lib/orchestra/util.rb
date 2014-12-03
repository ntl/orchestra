module Orchestra
  module Util
    extend self

    def extract_key_args hsh, *args
      defaults, args = extract_hash args
      unknown_args = hsh.keys - (args + defaults.keys)
      missing_args = args - hsh.keys
      unless unknown_args.empty? and missing_args.empty?
        raise ArgumentError, key_arg_error(unknown_args, missing_args)
      end
      (args + defaults.keys).map do |arg|
        hsh.fetch arg do defaults.fetch arg end
      end
    end

    def extract_hash ary
      if ary.last.is_a? Hash
        hsh = ary.pop
      else
        hsh = {}
      end
      [hsh, ary]
    end

    def recursively_symbolize obj
      case obj
      when Array
        obj.map &method(:recursively_symbolize)
      when Hash then
        obj.each_with_object Hash.new do |(k, v), out_hsh|
          out_hsh[k.to_sym] = recursively_symbolize v
        end
      else obj
      end
    end

    def to_lazy_thunk obj
      if obj.respond_to? :to_proc and not obj.is_a? Symbol
        obj
      else
        Proc.new do obj end
      end
    end

    def to_camel_case str
      str = "_#{str}"
      str.gsub!(%r{_[a-z]}) { |snake| snake.slice(1).upcase }
      str.gsub!('/', '::')
      str
    end

    def to_snake_case str
      str = str.gsub '::', '/'
      # Convert FOOBar => FooBar
      str.gsub! %r{[[:upper:]]{2,}} do |uppercase|
        bit = uppercase[0]
        bit << uppercase[1...-1].downcase
        bit << uppercase[-1]
        bit
      end
      # Convert FooBar => foo_bar
      str.gsub! %r{[[:lower:]][[:upper:]]+[[:lower:]]} do |camel|
        bit = camel[0]
        bit << '_'
        bit << camel[1..-1].downcase
      end
      str.downcase!
      str
    end

    def demodulize str
      split_namespaces(str).last
    end

    def deconstantize str
      split_namespaces(str).first
    end

    private

    def split_namespaces name
      name.split '::'
    end

    def key_arg_error unknown, missing
      str = "bad arguments. "
      if unknown.any?
        str.concat " unknown: #{unknown.join ', '}"
        str.concat "; " if missing.any?
      end
      if missing.any?
        str.concat " missing: #{missing.join ', '}"
      end
      str
    end
  end
end
