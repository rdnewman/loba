module Lba
  module Internal
    module Serialization
      # Serializes Strings, cutting long ones short.
      module StringNode
        # Longer strings are cut to this length, then marked "[+N chars]".
        # The marker doesn't count toward the limit. 500 is a guess.
        MAX_LENGTH = 500

        class << self
          # Serializes a String, cut to MAX_LENGTH characters if longer.
          #
          # @param value [String] the String to serialize
          # @return (see Lba::Internal::Serialization.serialize)
          def serialize(value:, **)
            omitted = value.length - MAX_LENGTH
            return untruncated(value) unless omitted.positive?

            {
              value: "#{value[0...MAX_LENGTH]} [+#{omitted} chars]",
              value_type: "String",
              inspected: false,
              truncated: true
            }
          end

        private

          def untruncated(value)
            { value:, value_type: "String", inspected: false, truncated: false }
          end
        end
      end
    end
  end
end
