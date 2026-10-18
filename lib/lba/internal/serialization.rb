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
        #   * +:value_type+ [String, nil] - the class name of +value+; for a
        #     subclass of String, Array, or Hash, that base class's name; +nil+
        #     for an anonymous class, or when rendering +value+ raised
        #   * +:rendered+ [Array<Hash>] - present only if any part is recorded as
        #     text rather than as itself: one +{ path:, as: }+ per part, where
        #     +as+ says why: +"inspect"+ or +"to_s"+ (no JSON form),
        #     +"non_finite"+ (NaN, Infinity), +"not_utf8"+ (a String that isn't
        #     text), or +"too_deep"+ (a container nested too deeply, rendered
        #     whole). A part whose rendering raised is in +:errors+ instead.
        #   * +:cut+ [Array<Hash>] - present only if any part was cut short: one
        #     +{ path:, omitted:, unit: }+ per part, +unit+ being +"chars"+ (a
        #     long String, still marked +" [+N chars]"+ in the value),
        #     +"entries"+ (an Array), or +"keys"+ (a Hash)
        #   * +:errors+ [Array<Hash>] - present only if rendering any part
        #     raised: one +{ path:, message: }+ per failure. A +path+, here and
        #     in +:rendered+, is the part's position (Array indexes and Hash
        #     keys) and +[]+ means the whole value. When the whole value failed it is the only key.
        #   * +:collided+ [Array<Hash>] - present only if a Hash had keys that
        #     JSON writes as the same text: one +{ path:, key:, pairs: }+ per
        #     key, +pairs+ listing every colliding pair as +#inspect+ text;
        #     +:value+ keeps the first pair
        #   An entry in +:rendered+, +:cut+, or +:errors+ about a Hash key
        #   itself, rather than its value, also has +key: true+.
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
