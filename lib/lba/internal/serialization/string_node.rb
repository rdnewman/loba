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
          # JSON text is UTF-8, so a String is recorded as-is only if it is
          # UTF-8 or converts to it. Anything else (binary data, invalid bytes)
          # is recorded as its +#inspect+ text, which is always valid UTF-8.
          #
          # @param value [String] the String to serialize
          # @return (see Lba::Internal::Serialization.serialize)
          def serialize(value:, **)
            text = as_utf8(value)

            if text
              cut(text)
            else
              cut(value.inspect).merge(inspected: true)
            end
          end

        private

          def cut(text)
            omitted = text.length - MAX_LENGTH
            return untruncated(text) unless omitted.positive?

            {
              value: "#{text[0...MAX_LENGTH]} [+#{omitted} chars]",
              value_type: "String",
              inspected: false,
              truncated: true
            }
          end

          def untruncated(text)
            { value: text, value_type: "String", inspected: false, truncated: false }
          end

          # Converting UTF-8 to UTF-8 checks nothing, so validity is checked
          # after converting.
          def as_utf8(value)
            return value if value.encoding == Encoding::UTF_8 && value.valid_encoding?

            converted = value.encode(Encoding::UTF_8)
            converted if converted.valid_encoding?
          rescue EncodingError
            nil
          end
        end
      end
    end
  end
end
