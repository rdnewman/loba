module Lba
  module Internal
    module Serialization
      # The shared base for ArrayNode and HashNode: bounded recursion into
      # children and aggregation of their flags, rendered parts, and errors. Each subclass
      # supplies #children_of, #values, #value_type, and #position.
      class ContainerNode
        # Deeper containers fall back to #inspect. This also stops a cycle,
        # which Ruby's own #inspect then handles safely. 5 is a guess.
        MAX_DEPTH = 5

        # Entries past this are never walked; a sentinel counts them. This
        # bounds the cost of a huge value. 50 is a guess.
        MAX_ENTRIES = 50

        # Shared by every child with no entries in a list, so it allocates
        # nothing.
        NONE = [].freeze

        # Serializes a container; shorthand for +new(...).serialize+.
        #
        # @return (see Lba::Internal::Serialization.serialize)
        def self.serialize(...) = new(...).serialize

        # Serializes the container's first MAX_ENTRIES children, unless it is
        # nested MAX_DEPTH or more deep.
        #
        # @param value [Array, Hash] the container to serialize
        # @param depth [Integer] how deeply +value+ is nested in the value being
        #   recorded
        # @param use_inspect [Boolean] +true+ to render a value with no JSON form
        #   with +#inspect+; +false+ to use +#to_s+
        def initialize(value:, depth: 0, use_inspect: true)
          @value = value
          @depth = depth
          @use_inspect = use_inspect
          return if depth >= MAX_DEPTH

          @children = children_of(value.first(MAX_ENTRIES)).map do |child|
            UnknownNode.serialize(value: child, depth: depth + 1, use_inspect:)
          end
        end

        # Assembles the container's result from its children, or renders the
        # whole container as text if it is nested MAX_DEPTH or more deep.
        #
        # @return (see Lba::Internal::Serialization.serialize)
        def serialize
          if depth >= MAX_DEPTH
            FallbackNode.serialize(value:, depth:, use_inspect:, as: "too_deep")
          else
            { value: values, value_type:, **listed(:rendered), truncated:, **listed(:errors) }
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

        # Where the child at +index+ sits in this container, for a path.
        def position(_index)
          raise NotImplementedError
        end

        # The children's entries in +list+ (+:rendered+ or +:errors+), keyed
        # by +list+, or nothing if none has any.
        def listed(list)
          entries = children.each_with_index.flat_map do |child, index|
            prefixed(child[list], index)
          end

          if entries.empty?
            {}
          else
            { list => entries }
          end
        end

        # A child's entries, with its position put in front of their paths.
        # The position is worked out only for a child that has entries.
        def prefixed(entries, index)
          return NONE unless entries

          entries.map { |entry| entry.merge(path: [position(index), *entry[:path]]) }
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
