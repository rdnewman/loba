module Lba
  module Internal
    module Serialization
      module FallbackNode
        class << self
          def serialize(value:, use_inspect: true, **)
            {
              value: rendered_value(value, use_inspect),
              value_type: value.class.name,
              inspected: true,
              truncated: false
            }
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
