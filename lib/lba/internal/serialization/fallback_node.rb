require_relative "base_node"

module Lba
  module Internal
    module Serialization
      class FallbackNode < BaseNode
        def self.handles?(_value) = true

        def serialize
          {
            value: rendered_value,
            value_type:,
            inspected: true,
            truncated:
          }
        end

      private

        def value_type = value.class.name

        def rendered_value
          if use_inspect
            value.inspect
          else
            value.to_s
          end
        end
      end
    end
  end
end
