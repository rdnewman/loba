RSpec.describe Lba::Internal::Serialization::NativeNode do
  describe ".serialize" do
    it "passes an Integer through unchanged" do
      result = described_class.serialize(value: 42)

      expect(result).to eq(
        value: 42,
        value_type: "Integer",
        inspected: false,
        truncated: false
      )
    end
  end

  describe ".handles?" do
    [42, 3.14, true, false, nil, :sym].each do |native_value|
      it "returns true for a #{native_value.class}" do
        expect(described_class.handles?(native_value)).to be true
      end
    end

    it "returns false for a String" do
      expect(described_class.handles?("hello")).to be false
    end

    it "returns false for a plain Object" do
      expect(described_class.handles?(Object.new)).to be false
    end
  end
end
