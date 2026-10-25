RSpec.describe Loba::Internal::Serialization::NativeNode do
  describe ".serialize" do
    it "passes an Integer through unchanged" do
      result = described_class.serialize(value: 42)

      expect(result).to eq(
        value: 42,
        value_type: "Integer"
      )
    end
  end
end
