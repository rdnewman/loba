RSpec.describe Loba::Internal::Serialization::UnknownNode do
  describe ".serialize", :aggregate_failures do
    [42, 3.14, true, false, nil, :sym].each do |native_value|
      it "dispatches a #{native_value.class} to NativeNode" do
        result = described_class.serialize(value: native_value)

        expect(result[:value]).to eq(native_value)
        expect(result[:value_type]).to eq(native_value.class.name)
      end
    end

    it "dispatches a Float to FloatNode, NaN handling included" do
      result = described_class.serialize(value: Float::NAN)

      expect(result).to include(value: "NaN")
    end

    it "dispatches a String to StringNode, truncation included" do
      max_length = Loba::Internal::Serialization::StringNode::MAX_LENGTH
      long_string = "a" * (max_length + 3)

      result = described_class.serialize(value: long_string)

      expect(result[:value]).to eq("#{'a' * max_length} [+3 chars]")
    end

    it "dispatches an Array to ArrayNode" do
      result = described_class.serialize(value: [1, 2])

      expect(result[:value]).to eq([1, 2])
      expect(result[:value_type]).to eq("Array")
    end

    it "dispatches a Hash to HashNode" do
      result = described_class.serialize(value: { a: 1 })

      expect(result[:value]).to eq(a: 1)
      expect(result[:value_type]).to eq("Hash")
    end

    it "dispatches a value with no dedicated node type to FallbackNode" do
      plain_object = Object.new

      result = described_class.serialize(value: plain_object)

      expect(result[:value]).to eq(plain_object.inspect)
      expect(result[:value_type]).to eq("Object")
    end

    # Subclasses such as HashWithIndifferentAccess must reach their structural
    # node. Exact-class dispatch would send them to FallbackNode.
    context "when given a subclass of a type with its own node" do
      it "dispatches a String subclass to StringNode" do
        string_subclass_value = Class.new(String).new("hello")

        result = described_class.serialize(value: string_subclass_value)

        expect(result[:value]).to eq("hello")
      end

      it "dispatches an Array subclass to ArrayNode" do
        array_subclass_value = Class.new(Array).new([1, 2])

        result = described_class.serialize(value: array_subclass_value)

        expect(result[:value]).to eq([1, 2])
      end

      it "dispatches a Hash subclass to HashNode" do
        hash_subclass_value = Class.new(Hash)[a: 1]

        result = described_class.serialize(value: hash_subclass_value)

        expect(result[:value]).to eq(a: 1)
      end
    end
  end
end
