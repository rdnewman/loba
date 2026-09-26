module Lba
  module Internal
    module Serialization
      # The shared base for ArrayNode and HashNode: bounded recursion into
      # children and aggregation of their flags. Each subclass supplies
      # #children_of, #values, and #value_type.
      class ContainerNode
        # Deeper containers fall back to #inspect. This also stops a cycle,
        # which Ruby's own #inspect then handles safely. 5 is a guess.
        MAX_DEPTH = 5

        # Entries past this are never walked; a sentinel counts them. This
        # bounds the cost of a huge value. 50 is a guess.
        MAX_ENTRIES = 50

        def self.serialize(...) = new(...).serialize

        def initialize(value:, depth: 0, use_inspect: true)
          @value = value
          @depth = depth
          @use_inspect = use_inspect
          return if depth >= MAX_DEPTH

          @children = children_of(value.first(MAX_ENTRIES)).map do |child|
            UnknownNode.serialize(value: child, depth: depth + 1, use_inspect:)
          end
        end

        def serialize
          if depth >= MAX_DEPTH
            FallbackNode.serialize(value:, depth:, use_inspect:)
          else
            { value: values, value_type:, inspected:, truncated: }
          end
        end

      private

        attr_reader :value, :depth, :use_inspect, :children

        def children_of(_entries)
          raise NotImplementedError
        end

        def values
          raise NotImplementedError
        end

        def inspected
          children.any? { _1[:inspected] }
        end

        def truncated
          oversized? || children.any? { _1[:truncated] }
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
