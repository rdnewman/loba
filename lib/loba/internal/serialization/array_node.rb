require_relative "container_node"

module Loba
  module Internal
    module Serialization
      # Serializes Arrays: each entry becomes a child.
      class ArrayNode < ContainerNode
      private

        def value_type = "Array"

        def children_of(entries) = entries

        def omitted_unit = "entries"

        def items = children.map { _1[:value] }

        def position(index) = index
      end
    end
  end
end
