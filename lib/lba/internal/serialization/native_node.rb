require_relative "base_node"

module Lba
  module Internal
    module Serialization
      class NativeNode < BaseNode
        TYPES = [
          Integer, Float, TrueClass, FalseClass, NilClass, Symbol
        ].freeze

        def self.handles?(value)
          TYPES.any? { value.instance_of?(_1) }
        end

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
