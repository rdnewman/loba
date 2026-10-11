require_relative "string_node"

module Lba
  module Internal
    module Serialization
      # Serializes values with no JSON form as text, from +#inspect+ or +#to_s+.
      module FallbackNode
        # Stands in for a value whose rendering raised.
        UNRENDERABLE = "(unrenderable)".freeze

        class << self
          # Serializes a value as text.
          #
          # The rendered text is cut exactly as a long String is. Rendering
          # runs the traced program's code, which can raise (a +BasicObject+ has
          # no +#inspect+; a custom one can fail); then the value is marked
          # UNRENDERABLE and the error is reported in +:errors+, with an empty
          # path for the value's own position. There is no fallback between
          # +#inspect+ and +#to_s+.
          #
          # @param value [Object] the value to serialize
          # @param use_inspect [Boolean] +true+ to render with +#inspect+; +false+
          #   to use +#to_s+
          # @param as [String, nil] why the value is recorded as text, for
          #   +:rendered+; +nil+ for the method it was rendered with,
          #   +"inspect"+ or +"to_s"+
          # @return (see Lba::Internal::Serialization.serialize)
          def serialize(value:, use_inspect: true, as: nil, **)
            text = rendered_value(value, use_inspect)
            value_type = value.class.name
          rescue StandardError => e
            unrenderable(e)
          else
            rendered = [{ path: [], as: as || method_used(use_inspect) }]
            StringNode.serialize(value: text).merge(value_type:, rendered:)
          end

        private

          def unrenderable(error)
            {
              value: UNRENDERABLE,
              value_type: nil,
              truncated: false,
              errors: [{ path: [], message: "#{error.class}: #{error.message}" }]
            }
          end

          def method_used(use_inspect)
            if use_inspect
              "inspect"
            else
              "to_s"
            end
          end

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
