module Lba
  module Internal
    module Serialization
      # The shared base for every concrete node: construction, the
      # `.serialize` class delegate, and the #serialize/#value_type contract.
      BaseNode = Data.define(:value, :depth, :use_inspect) do
        def self.serialize(...) = new(...).serialize

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
