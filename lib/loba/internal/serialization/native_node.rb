module Loba
  module Internal
    module Serialization
      # Serializes values JSON represents as they are: Integers, Floats, +true+,
      # +false+, and +nil+.
      module NativeNode
        # Serializes a JSON-native value as itself.
        #
        # @param value [Integer, Float, Boolean, nil] the value to serialize
        # @return (see Loba::Internal::Serialization.serialize)
        def self.serialize(value:, **)
          {
            value:,
            value_type: value.class.name
          }
        end
      end
    end
  end
end
