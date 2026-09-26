require_relative "base_node"

module Lba
  module Internal
    module Serialization
      class StringNode < BaseNode
        # Longer strings are cut to this length, then marked "[+N chars]".
        # The marker doesn't count toward the limit. 500 is a guess.
        MAX_LENGTH = 500

        def serialize
          omitted = value.length - MAX_LENGTH
          return untruncated unless omitted.positive?

          {
            value: "#{value[0...MAX_LENGTH]} [+#{omitted} chars]",
            value_type:,
            inspected:,
            truncated: true
          }
        end

      private

        def value_type = "String"

        def untruncated
          { value:, value_type:, inspected:, truncated: false }
        end
      end
    end
  end
end
