require_relative "container_node"

module Lba
  module Internal
    module Serialization
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
      end
    end
  end
end
