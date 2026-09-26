require_relative "base_node"
require_relative "native_node"
require_relative "string_node"
require_relative "array_node"
require_relative "hash_node"
require_relative "fallback_node"

module Lba
  module Internal
    module Serialization
      module UnknownNode
        # A pure dispatcher. It holds no state, so it skips the Data.define
        # object each real node builds.
        def self.serialize(value:, depth: 0, use_inspect: true)
          node_class(value).serialize(value:, depth:, use_inspect:)
        end

        # A case/when rather than asking each node in turn: the block yields in
        # `find` and `any?` dominate dispatch, which runs once per node. Native
        # types are listed inline because `when *SOME_ARRAY` is about twice as
        # slow.
        def self.node_class(value)
          case value
          when String
            StringNode
          when Integer, Float, TrueClass, FalseClass, NilClass, Symbol
            NativeNode
          when Array
            ArrayNode
          when Hash
            HashNode
          else
            FallbackNode
          end
        end
        private_class_method :node_class
      end
    end
  end
end
