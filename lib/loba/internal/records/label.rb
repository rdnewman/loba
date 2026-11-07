require_relative "../text"

module Loba
  module Internal
    module Records
      # Decides a record's label: an explicit one if usable, otherwise one
      # inferred from a Symbol argument.
      class Label
        # Decides the label; shorthand for +new(...).infer+.
        #
        # @return (see #infer)
        def self.infer(...) = new(...).infer

        # @param argument [Symbol, Object] the argument given to +Loba.value+
        # @param label [String, Symbol, Object, nil] the explicit label given, if
        #   any
        def initialize(argument:, label: nil)
          @argument = argument
          @label = label
        end

        # @return [String, nil] the explicit label, stripped, if it's a String
        #   or Symbol; with no explicit label, a +Symbol+ argument's name;
        #   otherwise +nil+ (including an explicit label of any other type)
        def infer
          explicit_label || inferred_label || nil
        end

      private

        attr_reader :argument, :label

        def explicit_label
          normalize(label) if coercible_label?
        end

        def inferred_label
          normalize(argument) if no_label? && symbol_argument?
        end

        def normalize(value)
          Text.make_utf8(value.to_s).strip
        end

        # The checks below use Module#=== rather than #is_a? or #nil?, which a
        # BasicObject argument or label lacks.

        def coercible_label?
          String === label || Symbol === label # rubocop:disable Style/CaseEquality
        end

        def no_label?
          NilClass === label # rubocop:disable Style/CaseEquality
        end

        def symbol_argument?
          Symbol === argument # rubocop:disable Style/CaseEquality
        end
      end
    end
  end
end
