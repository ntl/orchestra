module Orchestra
  class Step
    class Output
      attr :hsh, :step, :raw

      def self.process step, raw
        instance = new step, raw
        instance.massage
        instance.hsh
      end

      def initialize step, raw
        @step = step
        @raw = raw
      end

      def provisions
        step.provisions
      end

      def collection?
        step.collection?
      end

      def massage
        @raw.compact! if collection?
        @hsh = coerce_to_hash
        prune
        ensure_all_provisions_supplied!
      end

      def coerce_to_hash
        return Hash(raw) unless provisions.size == 1
        return raw if all_provisions_supplied? raw if raw.kind_of? Hash
        raise MissingProvisionError.new provisions if raw.nil?
        { provisions.first => raw }
      end

      def all_provisions_supplied? hsh = @hsh
        provisions.all? &included_in_output(hsh)
      end

      def missing_provisions
        provisions.reject &included_in_output
      end

      def included_in_output hsh = @hsh
        hsh.keys.method :include?
      end

      def prune
        hsh.select! do |key, _| provisions.include? key end
      end

      def ensure_all_provisions_supplied!
        return if all_provisions_supplied?
        raise MissingProvisionError.new missing_provisions
      end
    end
  end
end
