require_relative "native_node"
require_relative "float_node"
require_relative "string_node"
require_relative "array_node"
require_relative "hash_node"
require_relative "fallback_node"

module Lba
  module Internal
    module Serialization
      # Sends a value to the node for its kind.
      module UnknownNode
        # Serializes a value with the node for its kind.
        #
        # A pure dispatcher: every node answers .serialize(value:, depth:,
        # use_inspect:), whether it's a module or a class.
        #
        # @param value [Object] the value to serialize
        # @param depth [Integer] how deeply +value+ is nested in the value being
        #   recorded
        # @param use_inspect [Boolean] +true+ to render a value with no JSON form
        #   with +#inspect+; +false+ to use +#to_s+
        # @return (see Lba::Internal::Serialization.serialize)
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
          when Integer, TrueClass, FalseClass, NilClass, Symbol
            NativeNode
          when Float
            FloatNode
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
