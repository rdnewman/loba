RSpec.describe Lba::Internal::Serialization::FallbackNode do
  describe ".serialize", :aggregate_failures do
    it "falls back to #inspect for a value with no dedicated node type" do
      plain_object = Object.new

      result = described_class.serialize(value: plain_object)

      expect(result[:value]).to eq(plain_object.inspect)
      expect(result[:value_type]).to eq("Object")
      expect(result[:inspected]).to be true
      expect(result[:truncated]).to be false
    end
  end

  describe ".handles?" do
    it "returns true for any value" do
      expect(described_class.handles?(Object.new)).to be true
    end
  end
end
