module Lba
  module Internal
    class Label
      def self.infer(...) = new(...).infer

      def initialize(argument:, label: nil)
        @argument = argument
        @label = label
      end

      def infer
        if label.nil?
          infer_from_argument
        elsif coercible?
          normalize(label)
        end
      end

    private

      attr_reader :argument, :label

      def infer_from_argument
        return nil unless argument.is_a?(Symbol)

        normalize(argument)
      end

      def coercible?
        label.is_a?(String) || label.is_a?(Symbol)
      end

      def normalize(value)
        value.to_s.strip
      end
    end
  end
end
