module Lba
  module Internal
    # Decides a record's label: an explicit one if usable, otherwise one
    # inferred from a Symbol argument.
    class Label
      # Decides the label; shorthand for +new(...).infer+.
      #
      # @return (see #infer)
      def self.infer(...) = new(...).infer

      # @param argument [Symbol, Object] the argument given to +Lba.value+
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

      # Module#=== rather than #is_a?, which a BasicObject argument lacks.
      def infer_from_argument
        return nil unless Symbol === argument # rubocop:disable Style/CaseEquality

        normalize(argument)
      end

      def coercible?
        label.is_a?(String) || label.is_a?(Symbol)
      end

      def normalize(value)
        utf8(value.to_s).strip
      end

      # JSON text is UTF-8. A binary label's bytes are read as UTF-8, and any
      # bytes that aren't valid there become U+FFFD, so a label always writes.
      # Converting UTF-8 to UTF-8 checks nothing, so #scrub follows #encode.
      def utf8(text)
        if text.encoding == Encoding::BINARY
          text.dup.force_encoding(Encoding::UTF_8).scrub
        else
          text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace).scrub
        end
      end
    end
  end
end
