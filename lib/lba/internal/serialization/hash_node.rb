require_relative "container_node"

module Lba
  module Internal
    module Serialization
      # Serializes Hashes: keys and values both become children.
      class HashNode < ContainerNode
      private

        def value_type = "Hash"

        # Keys and values are children alike, in one flat list: key, value,
        # key, value. Their flags count toward the Hash's the same way.
        def children_of(pairs) = pairs.flatten(1)

        def omitted_unit = "keys"

        def items
          if colliding_groups.empty?
            all_pairs
          else
            kept_pairs
          end
        end

        def all_pairs
          children.each_slice(2).to_h { |key, entry| [key[:value], entry[:value]] }
        end

        # The pairs left after key collisions: the first of each.
        def kept_pairs
          pairs = children.each_slice(2).with_index
          pairs.each_with_object({}) do |((key, entry), pair_index), kept|
            kept[key[:value]] = entry[:value] unless lost_pair?(pair_index)
          end
        end

        # Keys sit at even indexes, each followed by its value.
        def key_child?(index) = index.even?

        # JSON holds a key only as text, so a container key is rendered whole
        # rather than walked: a path into it would lead nowhere.
        def serialize_child(child, index)
          if key_child?(index) && container?(child)
            FallbackNode.serialize(value: child, use_inspect:)
          else
            super
          end
        end

        def container?(child)
          child.is_a?(Array) || child.is_a?(Hash)
        end

        # A child's position is its pair's key, as JSON writes keys: as text.
        def position(index) = key_texts[index / 2]

        def counted?(index) = !lost_pair?(index / 2)

        # Keys that JSON writes as the same text would leave duplicate JSON
        # keys, and a JSON parser keeps only one. Each colliding pair is listed
        # as #inspect text (never #to_s, which shows :a and "a" alike): a pair
        # left out of the value has no path for anything inside it.
        def collisions
          colliding_groups.map do |pair_indexes|
            key = key_texts[pair_indexes.first]
            { path: [], key:, pairs: pair_indexes.map { pair_text(_1) } }
          end
        end

        def lost_pair?(pair_index)
          lost_pair_indexes.include?(pair_index)
        end

        def lost_pair_indexes
          @lost_pair_indexes ||= colliding_groups.flat_map { _1.drop(1) }
        end

        # Pair indexes sharing a key text, for each text more than one has.
        # Most Hashes have none, found without grouping.
        def colliding_groups
          @colliding_groups ||= if key_texts.uniq.size == key_texts.size
                                  NONE
                                else
                                  grouped_pair_indexes.select { _1.size > 1 }
                                end
        end

        def grouped_pair_indexes
          key_texts.each_index.group_by { key_texts[_1] }.values
        end

        def key_texts
          @key_texts ||= children.each_slice(2).map { |key, _entry| key_text(key[:value]) }
        end

        # Symbol#name, unlike #to_s, doesn't allocate a new String.
        def key_text(key_value)
          if key_value.is_a?(Symbol)
            key_value.name
          else
            key_value.to_s
          end
        end

        def pair_text(pair_index)
          value.first(MAX_ENTRIES)[pair_index].map { inspect_text(_1) }
        end

        def inspect_text(object)
          StringNode.serialize(value: object.inspect)[:value]
        rescue StandardError
          FallbackNode::UNRENDERABLE
        end
      end
    end
  end
end
