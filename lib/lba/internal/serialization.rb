require_relative "serialization/native_node"
require_relative "serialization/string_node"
require_relative "serialization/container_node"
require_relative "serialization/array_node"
require_relative "serialization/hash_node"
require_relative "serialization/fallback_node"
require_relative "serialization/unknown_node"

module Lba
  module Internal
    module Serialization
      # A node reader named `inspect` would replace Kernel#inspect, so the
      # option travels on as `use_inspect:`.
      def self.serialize(value:, depth: 0, inspect: true)
        UnknownNode.serialize(value:, depth:, use_inspect: inspect)
      end
    end
  end
end
