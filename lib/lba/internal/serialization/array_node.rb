require_relative "base_node"

module Lba
  module Internal
    module Serialization
      class ArrayNode < BaseNode
        # Containers recurse up to this many levels before falling back to
        # #inspect. This also bounds a circular structure's recursion -- it
        # can't exceed MAX_DEPTH regardless of the cycle, and Ruby's own
        # #inspect handles the resulting cycle safely once recursion stops.
        #
        # 5 is an unvalidated placeholder, not a measured value -- there's no
        # performance data yet showing where cost actually starts to matter.
        MAX_DEPTH = 5

        # An Array with more than this many entries has the rest dropped, then
        # gets one trailing sentinel entry appended showing how many were
        # dropped -- entries beyond this limit are never even recursed into,
        # so a huge accidental value doesn't cost more than this to process.
        #
        # 50 is an unvalidated placeholder, same caveat as MAX_DEPTH above: no
        # performance data yet showing where cost actually starts to matter.
        MAX_ENTRIES = 50

        def self.handles?(value) = value.is_a?(Array)

        def initialize(value:, depth: 0)
          if depth < MAX_DEPTH
            @elements = value.first(MAX_ENTRIES).map do |entry|
              UnknownNode.serialize(value: entry, depth: depth + 1)
            end
          end

          super
        end

        def serialize
          if depth >= MAX_DEPTH
            FallbackNode.serialize(value:, depth:)
          else
            { value: values, value_type:, inspected:, truncated: }
          end
        end

      private

        attr_reader :elements

        def value_type = "Array"

        def values
          substituted = elements.map { _1[:value] }
          return substituted unless oversized?

          substituted + ["[+#{omitted_count} more entries]"]
        end

        def inspected
          elements.any? { _1[:inspected] }
        end

        def truncated
          oversized? || elements.any? { _1[:truncated] }
        end

        def omitted_count
          value.size - MAX_ENTRIES
        end

        def oversized?
          value.size > MAX_ENTRIES
        end
      end
    end
  end
end
