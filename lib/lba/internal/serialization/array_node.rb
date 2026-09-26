require_relative "container_node"

module Lba
  module Internal
    module Serialization
      class ArrayNode < ContainerNode
      private

        def value_type = "Array"

        def children_of(entries) = entries

        def values
          return items unless oversized?

          items + ["[+#{omitted_count} more entries]"]
        end

        def items = children.map { _1[:value] }
      end
    end
  end
end
