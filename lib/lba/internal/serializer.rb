module Lba
  module Internal
    class Serializer
      def self.serialize(...) = new(...).serialize

      def initialize(value)
        @value = value
      end

      def serialize
        {
          value: value,
          value_type: value.class.name,
          inspected: false,
          truncated: false
        }
      end

    private

      attr_reader :value
    end
  end
end
