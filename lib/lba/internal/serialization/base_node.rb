module Lba
  module Internal
    module Serialization
      # Shared interface for every node type: construction, the class-level
      # `.serialize(...) = new(...).serialize` delegate every subclass inherits,
      # and the abstract instance contract each concrete node must implement.
      # No shared behavior beyond that -- each concrete node's own code is
      # nothing but its distinguishing #serialize logic.
      BaseNode = Data.define(:value, :depth, :use_inspect) do
        def self.serialize(...) = new(...).serialize

        def self.handles?(_value) = false

        def initialize(value:, depth: 0, use_inspect: true)
          super
        end

        def serialize
          raise NotImplementedError
        end

      private

        def value_type
          raise NotImplementedError
        end

        # rubocop:disable-next Naming/PredicateMethod -- schema field is `inspected`, no `?`
        def inspected = false

        # rubocop:disable-next Naming/PredicateMethod -- schema field is `truncated`, no `?`
        def truncated = false
      end
    end
  end
end
