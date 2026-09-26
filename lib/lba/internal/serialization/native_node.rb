module Lba
  module Internal
    module Serialization
      # Serializes values JSON represents as they are: Integers, Floats, +true+,
      # +false+, +nil+, and Symbols (which JSON writes as strings).
      module NativeNode
        # Serializes a JSON-native value as itself.
        #
        # @param value [Integer, Float, Boolean, nil, Symbol] the value to serialize
        # @return (see Lba::Internal::Serialization.serialize)
        def self.serialize(value:, **)
          {
            value:,
            value_type: value.class.name,
            inspected: false,
            truncated: false
          }
        end
      end
    end
  end
end
