require_relative "string_node"

module Loba
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
          # no +#inspect+; a custom one can fail) or return something other
          # than a String; then the value is marked UNRENDERABLE and the error
          # is reported in +:errors+, with an empty path for the value's own
          # position. There is no fallback between +#inspect+ and +#to_s+.
          #
          # @param value [Object] the value to serialize
          # @param use_inspect [Boolean] +true+ to render with +#inspect+; +false+
          #   to use +#to_s+
          # @param as [String, nil] why the value is recorded as text, for
          #   +:rendered+; +nil+ for the method it was rendered with,
          #   +"inspect"+ or +"to_s"+
          # @return (see Loba::Internal::Serialization.serialize)
          def serialize(value:, use_inspect: true, as: nil, **)
            text = rendered_text(value, use_inspect)
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

          def rendered_text(value, use_inspect)
            text = rendered_value(value, use_inspect)
            raise TypeError, not_a_string(text, use_inspect) unless string?(text)

            text
          end

          def not_a_string(text, use_inspect)
            "##{method_used(use_inspect)} returned #{class_of(text)}, not a String"
          end

          # Module#=== and Kernel#class via bind_call also work on a BasicObject,
          # which has neither #is_a? nor #class of its own.
          def string?(text)
            ::String === text # rubocop:disable Style/CaseEquality -- see above
          end

          def class_of(object) = ::Kernel.instance_method(:class).bind_call(object)

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
