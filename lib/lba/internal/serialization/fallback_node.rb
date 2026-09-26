require_relative "string_node"

module Lba
  module Internal
    module Serialization
      module FallbackNode
        class << self
          # The rendered text is cut exactly as a long String is.
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
