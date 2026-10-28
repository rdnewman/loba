module Loba
  module Internal
    module Serialization
      # The shared base for ArrayNode and HashNode: bounded recursion into
      # children, and gathering of their rendered parts, cuts, errors, and
      # key collisions. Each subclass supplies #children_of, #items,
      # #value_type, #omitted_unit, and #position.
      class ContainerNode
        # Deeper containers are rendered as text, by #inspect (or #to_s with
        # inspect: false). This also stops a cycle, which Ruby's own #inspect
        # then handles safely. 5 is a guess.
        MAX_DEPTH = 5

        # Entries past this are never walked; the container's :cut entry counts
        # them. This bounds the cost of a huge value. 50 is a guess.
        MAX_ENTRIES = 50

        # Shared by every child with no entries in a list, so it allocates
        # nothing.
        NONE = [].freeze

        # Serializes a container; shorthand for +new(...).serialize+.
        #
        # @return (see Loba::Internal::Serialization.serialize)
        def self.serialize(...) = new(...).serialize

        # Serializes the container's first MAX_ENTRIES entries, unless it is
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

          @children = children_of(value.first(MAX_ENTRIES)).each_with_index.map do |child, index|
            serialize_child(child, index)
          end
        end

        # Assembles the container's result from its children, or renders the
        # whole container as text if it is nested MAX_DEPTH or more deep.
        #
        # @return (see Loba::Internal::Serialization.serialize)
        def serialize
          if depth >= MAX_DEPTH
            FallbackNode.serialize(value:, depth:, use_inspect:, as: "too_deep")
          else
            {
              value: items, value_type:, **listed(:rendered), **listed(:cut, own: own_cut),
              **listed(:errors), **listed(:collided, own: collisions)
            }
          end
        end

      private

        attr_reader :value, :depth, :use_inspect, :children

        def children_of(_entries)
          raise NotImplementedError
        end

        def items
          raise NotImplementedError
        end

        # What an omitted entry is called in a :cut entry: "entries" or "keys".
        def omitted_unit
          raise NotImplementedError
        end

        # Where the child at +index+ sits in this container, for a path.
        def position(_index)
          raise NotImplementedError
        end

        # Whether the child at +index+ is a key. A Hash's keys are children
        # too, so their entries say so.
        def key_child?(_index) = false

        def serialize_child(child, _index)
          UnknownNode.serialize(value: child, depth: depth + 1, use_inspect:)
        end

        # Whether the child at +index+ is in the value, so its flags and
        # entries count. A Hash leaves out pairs whose keys collide.
        def counted?(_index) = true

        # This container's own key collisions; see HashNode.
        def collisions = NONE

        # The entries in +list+ (+:rendered+, +:cut+, +:errors+, or +:collided+): this
        # container's +own+, then its counted children's. Keyed by +list+, or
        # nothing if there are none.
        def listed(list, own: NONE)
          if own.empty? && children.none? { _1[list] }
            return {}
          end

          entries = children.each_with_index.flat_map do |child, index|
            next NONE unless counted?(index)

            prefixed(child[list], index)
          end
          entries = own + entries unless own.empty?

          if entries.empty?
            {}
          else
            { list => entries }
          end
        end

        # A child's entries, with its position put in front of their paths,
        # and marked if the child is a key. The position is worked out only
        # for a child that has entries.
        def prefixed(entries, index)
          return NONE unless entries

          entries.map do |entry|
            entry.merge(path: [position(index), *entry[:path]], **key_mark(index))
          end
        end

        def key_mark(index)
          if key_child?(index)
            { key: true }
          else
            {}
          end
        end

        # The container's own cut, if it has more entries than are walked.
        def own_cut
          if oversized?
            [{ path: [], omitted: omitted_count, unit: omitted_unit }]
          else
            NONE
          end
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
