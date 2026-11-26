require_relative "string_node"

module Loba
  module Internal
    module Serialization
      # Serializes Symbols, which JSON writes as strings.
      module SymbolNode
        class << self
          # Serializes a Symbol as itself, or if it's long, as its name cut as
          # a long String is: a Symbol can come from runtime data (+to_sym+ on
          # a parsed key). A Symbol whose name can't become UTF-8 (binary data,
          # or bytes another encoding has no UTF-8 for) can't be written as
          # JSON, so like a String that isn't text, it is recorded as its
          # +#inspect+ text, cut if long.
          #
          # @param value [Symbol] the Symbol to serialize
          # @return (see Loba::Internal::Serialization.serialize)
          def serialize(value:, **)
            if text?(value)
              as_text(value)
            else
              rendered_text(value)
            end
          end

        private

          def as_text(value)
            if value.length > Text::Truncated::MAX_LENGTH
              StringNode.serialize(value: value.name).merge(value_type: value.class.name)
            else
              { value:, value_type: value.class.name }
            end
          end

          # Plain ASCII is text in any encoding, and Ruby refuses to make a UTF-8
          # Symbol with invalid bytes; anything else is converted to find out.
          def text?(value)
            name = value.name
            name.ascii_only? || name.encoding == Encoding::UTF_8 || converts_to_utf8?(name)
          end

          def converts_to_utf8?(name)
            name.encode(Encoding::UTF_8)
            true
          rescue EncodingError
            false
          end

          def rendered_text(value)
            StringNode.serialize(value: value.inspect).merge(
              value_type: value.class.name,
              rendered: [{ path: [], as: "not_utf8" }]
            )
          end
        end
      end
    end
  end
end
