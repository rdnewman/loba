require_relative "base_node"

module Lba
  module Internal
    module Serialization
      class HashNode < BaseNode
        # Deeper containers fall back to #inspect. This also stops a cycle,
        # which Ruby's own #inspect then handles safely. 5 is a guess.
        MAX_DEPTH = 5

        # Pairs past this are never walked; one trailing sentinel counts them.
        # This bounds the cost of a huge value. 50 is a guess.
        MAX_ENTRIES = 50

        def initialize(value:, depth: 0, use_inspect: true)
          if depth < MAX_DEPTH
            # Each pair goes through ArrayNode as [key, entry], reusing its
            # recursion and flag aggregation. Passing `depth:` unchanged keeps
            # the pair wrapper from counting as a nesting level.
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
