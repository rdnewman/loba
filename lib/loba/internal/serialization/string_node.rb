require_relative "../text"

module Loba
  module Internal
    module Serialization
      # Serializes Strings, cutting long ones short.
      module StringNode
        class << self
          # Serializes a String, cut as Text::Truncated cuts text if longer.
          #
          # JSON text is UTF-8, so a String is recorded as-is only if it is
          # UTF-8 or converts to it. Anything else (binary data, invalid bytes)
          # is recorded as its +#inspect+ text, which is always valid UTF-8.
          #
          # @param value [String] the String to serialize
          # @return (see Loba::Internal::Serialization.serialize)
          def serialize(value:, **)
            text = as_utf8(value)

            if text
              cut(text)
            else
              cut(value.inspect).merge(rendered: [{ path: [], as: "not_utf8" }])
            end
          end

        private

          def cut(text)
            truncated = Text::Truncated.new(text)
            return uncut(text) unless truncated.cut?

            {
              value: truncated.to_s,
              value_type: "String",
              cut: [{ path: [], omitted: truncated.chars_cut, unit: "chars" }]
            }
          end

          def uncut(text)
            { value: text, value_type: "String" }
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
