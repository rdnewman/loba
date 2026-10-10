require_relative "serialization/native_node"
require_relative "serialization/float_node"
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
      class << self
        # Serializes a value.
        #
        # @note A node reader named `inspect` would replace Kernel#inspect, so
        #   the option travels on as `use_inspect:`.
        #
        # @param value [Object] the value to serialize
        # @param depth [Integer] how deeply +value+ is nested in the value being
        #   recorded; containers at +ContainerNode::MAX_DEPTH+ are rendered as
        #   text
        # @param inspect [Boolean] +true+ to render a value with no JSON form
        #   with +#inspect+; +false+ to use +#to_s+
        # @return [Hash{Symbol => Object}] the serialized value:
        #   * +:value+ - the JSON-ready form of +value+
        #   * +:value_type+ [String] - the class name of +value+
        #   * +:inspected+ [Boolean] - whether any part was rendered as text
        #   * +:truncated+ [Boolean] - whether any part was cut short
        #   * +:errors+ [Array<Hash>] - present only if rendering any part
        #     raised: one +{ path:, message: }+ per failure, where +path+ is the
        #     part's position (Array indexes and Hash keys) and +[]+ means the
        #     whole value. When the whole value failed it is the only key.
        def serialize(value:, depth: 0, inspect: true)
          result = UnknownNode.serialize(value:, depth:, use_inspect: inspect)

          if whole_value_failed?(result)
            result.slice(:errors)
          else
            result
          end
        end

      private

        def whole_value_failed?(result)
          result.fetch(:errors, []).any? { |error| error[:path].empty? }
        end
      end
    end
  end
end
