require_relative "base_node"

module Lba
  module Internal
    module Serialization
      class FallbackNode < BaseNode
        def self.handles?(_value) = true

        def serialize
          {
            value: value.inspect,
            value_type:,
            inspected: true,
            truncated:
          }
        end

      private

        def value_type = value.class.name
      end
    end
  end
end
