require_relative "base_node"

module Lba
  module Internal
    module Serialization
      class ArrayNode < BaseNode
        # Deeper containers fall back to #inspect. This also stops a cycle,
        # which Ruby's own #inspect then handles safely. 5 is a guess.
        MAX_DEPTH = 5

        # Entries past this are never walked; one trailing sentinel counts
        # them. This bounds the cost of a huge value. 50 is a guess.
        MAX_ENTRIES = 50

        def initialize(value:, depth: 0, use_inspect: true)
          if depth < MAX_DEPTH
            @elements = value.first(MAX_ENTRIES).map do |entry|
              UnknownNode.serialize(value: entry, depth: depth + 1, use_inspect:)
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
