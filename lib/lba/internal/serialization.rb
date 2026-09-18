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
      def self.serialize(...) = UnknownNode.serialize(...)
    end
  end
end
