require_relative "string_node"

module Lba
  module Internal
    module Serialization
      # Serializes values with no JSON form as text, from +#inspect+ or +#to_s+.
      module FallbackNode
        class << self
          # Serializes a value as text.
          #
          # The rendered text is cut exactly as a long String is.
          #
          # @param value [Object] the value to serialize
          # @param use_inspect [Boolean] +true+ to render with +#inspect+; +false+
          #   to use +#to_s+
          # @return (see Lba::Internal::Serialization.serialize)
          def serialize(value:, use_inspect: true, **)
            StringNode
              .serialize(value: rendered_value(value, use_inspect))
              .merge(value_type: value.class.name, inspected: true)
          end

        private

          def rendered_value(value, use_inspect)
            if use_inspect
              value.inspect
            else
              value.to_s
            end
          end
        end
      end
    end
  end
end
