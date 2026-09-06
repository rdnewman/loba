RSpec.describe Lba::Internal::Serializer do
  describe ".serialize" do
    it "passes an Integer through unchanged" do
      result = described_class.serialize(42)

      expect(result).to eq(
        value: 42,
        value_type: "Integer",
        inspected: false,
        truncated: false
      )
    end

    it "passes a Float through unchanged" do
      result = described_class.serialize(3.14)

      expect(result).to eq(
        value: 3.14,
        value_type: "Float",
        inspected: false,
        truncated: false
      )
    end

    it "passes a String through unchanged" do
      result = described_class.serialize("hello")

      expect(result).to eq(
        value: "hello",
        value_type: "String",
        inspected: false,
        truncated: false
      )
    end

    it "passes true through unchanged" do
      result = described_class.serialize(true)

      expect(result).to eq(
        value: true,
        value_type: "TrueClass",
        inspected: false,
        truncated: false
      )
    end

    it "passes false through unchanged" do
      result = described_class.serialize(false)

      expect(result).to eq(
        value: false,
        value_type: "FalseClass",
        inspected: false,
        truncated: false
      )
    end

    it "passes nil through unchanged" do
      result = described_class.serialize(nil)

      expect(result).to eq(
        value: nil,
        value_type: "NilClass",
        inspected: false,
        truncated: false
      )
    end

    # Symbol isn't a JSON type, but JSON.generate coerces it to a string
    # automatically (Writer's job, not Serializer's) -- value_type still
    # preserves that this was originally a Symbol, not a String.
    it "passes a Symbol through unchanged" do
      result = described_class.serialize(:foo)

      expect(result).to eq(
        value: :foo,
        value_type: "Symbol",
        inspected: false,
        truncated: false
      )
    end
  end
end
