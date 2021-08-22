require_relative 'value/value_helper'

module Loba
  module Internal
    # Internal module for examining a value in support of Loba.value
    module Value
      module_function

      # Retrieve a value used in code.
      #
      # @param argument [Symbol, Object] the value or variable for which information is
      #   to be retrieved
      #   * If a symbol, it is assumed to be a reference to a variable
      #     and a label can be inferred.
      #   * If any other type, it is assumed to be a literal value to
      #     and a label should be supplied when instantiated.
      # @param label [String] when provided, an explicit label to use; will override any
      #   possible inferred label
      # @param inspect [Boolean] when true, force #inspect to be called against
      #   `argument` when evaluating
      # @param depth_offset [Integer] depth in call stack to start evaluation from
      #
      # @return [Hash] various detail about the value being analyzed
      #   * :tag => [String] method name (wrapped in square brackets)
      #   * :line => [String] code line reference
      #   * :value => [String] value of argument (if nil, '-nil-' is returned)
      #   * :label => [String] label, ending with ":"
      #     (if not possible to infer, '[unknown value]' is returned)
      def phrases(argument:, label: nil, inspect: true, depth_offset: 0)
        depth = depth_offset.nil? ? 0 : depth_offset.to_i
        {
          tag: ValueHelper.tag(depth: depth + 1),
          line: ValueHelper.line(depth: depth + 1),
          value: ValueHelper.value(argument: argument, inspect: inspect, depth: depth + 1),
          label: ValueHelper.label(argument: argument, explicit_label: label)
        }
      end
    end
  end
end
