RSpec.describe Lba::Internal::Serialization::FallbackNode do
  describe ".serialize", :aggregate_failures do
    it "falls back to #inspect for a value with no dedicated node type" do
      plain_object = object_with_distinct_inspect

      result = described_class.serialize(value: plain_object)

      expect(result[:value]).to eq(plain_object.inspect)
      expect(result[:value]).not_to eq(plain_object.to_s)
      expect(result[:value_type]).to eq("Object")
      expect(result[:inspected]).to be true
      expect(result[:truncated]).to be false
    end

    it "falls back to #to_s instead when use_inspect is false" do
      plain_object = object_with_distinct_inspect

      result = described_class.serialize(value: plain_object, use_inspect: false)

      expect(result[:value]).to eq(plain_object.to_s)
      expect(result[:value]).not_to eq(plain_object.inspect)
      expect(result[:inspected]).to be true
    end
  end
end
