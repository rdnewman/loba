require_relative "base_node"

module Lba
  module Internal
    module Serialization
      class StringNode < BaseNode
        # A String longer than this is cut to exactly this many characters,
        # then has a "[+N chars]" marker appended showing how many were
        # dropped -- the marker's own length isn't counted against this limit.
        #
        # 500 is an unvalidated placeholder, not a measured value -- there's no
        # performance data yet showing where cost actually starts to matter.
        MAX_LENGTH = 500

        def self.handles?(value) = value.is_a?(String)

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
