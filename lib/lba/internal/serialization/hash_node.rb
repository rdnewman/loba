require_relative "base_node"

module Lba
  module Internal
    module Serialization
      class HashNode < BaseNode
        # Containers recurse up to this many levels before falling back to
        # #inspect. This also bounds a circular structure's recursion -- it
        # can't exceed MAX_DEPTH regardless of the cycle, and Ruby's own
        # #inspect handles the resulting cycle safely once recursion stops.
        #
        # 5 is an unvalidated placeholder, not a measured value -- there's no
        # performance data yet showing where cost actually starts to matter.
        MAX_DEPTH = 5

        # A Hash with more than this many pairs has the rest dropped, then
        # gets one trailing sentinel entry appended showing how many were
        # dropped -- entries beyond this limit are never even recursed into,
        # so a huge accidental value doesn't cost more than this to process.
        #
        # 50 is an unvalidated placeholder, same caveat as MAX_DEPTH above: no
        # performance data yet showing where cost actually starts to matter.
        MAX_ENTRIES = 50

        def self.handles?(value) = value.is_a?(Hash)

        def initialize(value:, depth: 0, use_inspect: true)
          if depth < MAX_DEPTH
            # Each pair is serialized as a plain 2-element Array -- that's
            # exactly what a Hash entry already is -- so ArrayNode's own
            # recursion and inspected/truncated aggregation apply unchanged.
            # Passing `depth:` here (not `depth + 1`) keeps a pair from
            # counting as its own nesting level: ArrayNode's internal +1 is
            # the only place depth actually advances, matching how a key and
            # value would be dispatched directly without the pair wrapper.
            @pairs = value.first(MAX_ENTRIES).map do |key, entry|
              ArrayNode.serialize(value: [key, entry], depth:, use_inspect:)
            end
          end

          super
        end

        def serialize
          if depth >= MAX_DEPTH
            FallbackNode.serialize(value:, depth:, use_inspect:)
          else
            { value: values, value_type:, inspected:, truncated: }
          end
        end

      private

        attr_reader :pairs

        def value_type = "Hash"

        def oversized?
          value.size > MAX_ENTRIES
        end

        def omitted_count
          value.size - MAX_ENTRIES
        end

        def values
          substituted = pairs.to_h { _1[:value] }
          return substituted unless oversized?

          substituted.merge("[+#{omitted_count} more keys]" => true)
        end

        def inspected
          pairs.any? { _1[:inspected] }
        end

        def truncated
          oversized? || pairs.any? { _1[:truncated] }
        end
      end
    end
  end
end
