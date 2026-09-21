require_relative "serialization/base_node"
require_relative "serialization/native_node"
require_relative "serialization/string_node"
require_relative "serialization/array_node"
require_relative "serialization/hash_node"
require_relative "serialization/fallback_node"
require_relative "serialization/unknown_node"

module Lba
  module Internal
    module Serialization
      # `inspect:` is renamed to `use_inspect:` for everything past this point:
      #   BaseNode is a Data.define, and a field named `inspect` would shadow
      #   Kernel#inspect on every node instance (verified: Data.define(:inspect)
      #   makes #inspect return the field's value instead of the normal
      #   introspection string).
      def self.serialize(value:, depth: 0, inspect: true)
        UnknownNode.serialize(value:, depth:, use_inspect: inspect)
      end
    end
  end
end
