require_relative "base_node"

module Lba
  module Internal
    module Serialization
      class NativeNode < BaseNode
        def serialize
          {
            value:,
            value_type: value.class.name,
            inspected:,
            truncated:
          }
        end
      end
    end
  end
end
