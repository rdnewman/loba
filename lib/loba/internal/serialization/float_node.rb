require_relative "native_node"
require_relative "fallback_node"

module Loba
  module Internal
    module Serialization
      # Serializes Floats: a finite one as itself, and NaN or Infinity, which
      # JSON has no form for, as text.
      module FloatNode
        # Serializes a Float.
        #
        # @param value [Float] the Float to serialize
        # @return (see Loba::Internal::Serialization.serialize)
        def self.serialize(value:, **)
          if value.finite?
            NativeNode.serialize(value:)
          else
            FallbackNode.serialize(value:, as: "non_finite")
          end
        end
      end
    end
  end
end
