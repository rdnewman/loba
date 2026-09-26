module Lba
  module Internal
    module Serialization
      module NativeNode
        def self.serialize(value:, **)
          {
            value:,
            value_type: value.class.name,
            inspected: false,
            truncated: false
          }
        end
      end
    end
  end
end
