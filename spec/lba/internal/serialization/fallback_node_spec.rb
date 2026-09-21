RSpec.describe Lba::Internal::Serialization::FallbackNode do
  describe ".serialize", :aggregate_failures do
    # #to_s and #inspect must actually differ for this value, or an assertion
    # comparing against one of them can't tell the two code paths apart -- a
    # bare Object.new's #to_s and #inspect are identical, so this needs an
    # instance variable to make #inspect's ivar dump diverge from #to_s.
    let(:plain_object) do
      object = Object.new
      object.instance_variable_set(:@x, 1)
      object
    end

    it "falls back to #inspect for a value with no dedicated node type" do
      result = described_class.serialize(value: plain_object)

      expect(result[:value]).to eq(plain_object.inspect)
      expect(result[:value]).not_to eq(plain_object.to_s)
      expect(result[:value_type]).to eq("Object")
      expect(result[:inspected]).to be true
      expect(result[:truncated]).to be false
    end

    it "falls back to #to_s instead when use_inspect is false" do
      result = described_class.serialize(value: plain_object, use_inspect: false)

      expect(result[:value]).to eq(plain_object.to_s)
      expect(result[:value]).not_to eq(plain_object.inspect)
      expect(result[:inspected]).to be true
    end
  end

  describe ".handles?" do
    it "returns true for any value" do
      expect(described_class.handles?(Object.new)).to be true
    end
  end
end
