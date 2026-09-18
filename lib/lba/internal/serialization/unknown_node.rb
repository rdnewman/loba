require_relative "base_node"
require_relative "native_node"
require_relative "string_node"
require_relative "array_node"
require_relative "hash_node"
require_relative "fallback_node"

module Lba
  module Internal
    module Serialization
      class UnknownNode < BaseNode
        # Checked in order; FallbackNode's handles? is always true, so it's the
        # last resort every other type gets a chance to claim first.
        CANDIDATE_NODES = [StringNode, NativeNode, ArrayNode, HashNode, FallbackNode].freeze

        def serialize
          node_class.serialize(value:, depth:)
        end

      private

        def node_class
          CANDIDATE_NODES.find { _1.handles?(value) }
        end
      end
    end
  end
end
