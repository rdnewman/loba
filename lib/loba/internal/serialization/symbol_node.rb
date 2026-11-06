require_relative "string_node"

module Loba
  module Internal
    module Serialization
      # Serializes Symbols, which JSON writes as strings.
      module SymbolNode
        class << self
          # Serializes a Symbol as itself. A binary Symbol can't be written as
          # JSON, so like a String that isn't text, it is recorded as its
          # +#inspect+ text, cut if long.
          #
          # @param value [Symbol] the Symbol to serialize
          # @return (see Loba::Internal::Serialization.serialize)
          def serialize(value:, **)
            if value.encoding == Encoding::BINARY
              rendered_text(value)
            else
              { value:, value_type: value.class.name }
            end
          end

        private

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
