require_relative "container_node"

module Lba
  module Internal
    module Serialization
      # Serializes Hashes: keys and values both become children, and an extra
      # key counts any pairs past ContainerNode::MAX_ENTRIES.
      class HashNode < ContainerNode
      private

        def value_type = "Hash"

        # Keys and values are children alike, in one flat list: key, value,
        # key, value. Their flags count toward the Hash's the same way.
        def children_of(pairs) = pairs.flatten(1)

        def values
          return items unless oversized?

          items.merge("[+#{omitted_count} more keys]" => true)
        end

        def items
          children.each_slice(2).to_h do |key, entry|
            [key[:value], entry[:value]]
          end
        end

        # A child's position is its pair's key, as JSON writes keys: as text.
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

        def position(index)
          key_index = index - (index % 2)
          children[key_index][:value].to_s
        end
      end
    end
  end
end
