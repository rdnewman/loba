module Lba
  module Internal
    # Decides a record's label: an explicit one if usable, otherwise one
    # inferred from a Symbol argument.
    class Label
      # Decides the label; shorthand for +new(...).infer+.
      #
      # @return (see #infer)
      def self.infer(...) = new(...).infer

      # @param argument [Symbol, Object] the argument given to +Lba.val+
      # @param label [String, Symbol, Object, nil] the explicit label given, if any
      def initialize(argument:, label: nil)
        @argument = argument
        @label = label
      end

      # @return [String, nil] the explicit label, stripped, if it's a String or
      #   Symbol; with no explicit label, a +Symbol+ argument's name; otherwise
      #   +nil+ (including an explicit label of any other type)
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
