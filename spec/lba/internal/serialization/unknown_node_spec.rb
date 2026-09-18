RSpec.describe Lba::Internal::Serialization::UnknownNode do
  describe ".serialize", :aggregate_failures do
    [42, 3.14, true, false, nil, :sym].each do |native_value|
      it "dispatches a #{native_value.class} to NativeNode" do
        result = described_class.serialize(value: native_value)

        expect(result[:value]).to eq(native_value)
        expect(result[:value_type]).to eq(native_value.class.name)
        expect(result[:inspected]).to be false
        expect(result[:truncated]).to be false
      end
    end

    it "dispatches a String to StringNode, truncation included" do
      long_string = "a" * (Lba::Internal::Serialization::StringNode::MAX_LENGTH + 3)

      max_length = Lba::Internal::Serialization::StringNode::MAX_LENGTH

      result = described_class.serialize(value: long_string)

      expect(result[:value]).to eq("#{'a' * max_length} [+3 chars]")
      expect(result[:truncated]).to be true
    end

    it "dispatches a value with no dedicated node type to FallbackNode" do
      plain_object = Object.new

      result = described_class.serialize(value: plain_object)

      expect(result[:value]).to eq(plain_object.inspect)
      expect(result[:value_type]).to eq("Object")
      expect(result[:inspected]).to be true
    end
  end
end
