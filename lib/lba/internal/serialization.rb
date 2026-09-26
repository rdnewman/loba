require_relative "serialization/native_node"
require_relative "serialization/string_node"
require_relative "serialization/container_node"
require_relative "serialization/array_node"
require_relative "serialization/hash_node"
require_relative "serialization/fallback_node"
require_relative "serialization/unknown_node"

module Lba
  module Internal
    # Turns any Ruby value into a JSON-ready form, with flags saying how
    # faithfully it was captured. Each kind of value has its own node;
    # UnknownNode picks it.
    module Serialization
      # Serializes a value.
      #
      # @note A node reader named `inspect` would replace Kernel#inspect, so the
      #   option travels on as `use_inspect:`.
      #
      # @param value [Object] the value to serialize
      # @param depth [Integer] how deeply +value+ is nested in the value being
      #   recorded; containers at +ContainerNode::MAX_DEPTH+ are rendered as text
      # @param inspect [Boolean] +true+ to render a value with no JSON form with
      #   +#inspect+; +false+ to use +#to_s+
      # @return [Hash{Symbol => Object}] the serialized value:
      #   * +:value+ - the JSON-ready form of +value+
      #   * +:value_type+ [String] - the class name of +value+
      #   * +:inspected+ [Boolean] - whether any part was rendered as text
      #   * +:truncated+ [Boolean] - whether any part was cut short
      def self.serialize(value:, depth: 0, inspect: true)
        UnknownNode.serialize(value:, depth:, use_inspect: inspect)
      end
    end
  end
end
