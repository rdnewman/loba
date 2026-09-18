RSpec.describe Lba::Internal::Serialization::StringNode do
  describe ".serialize", :aggregate_failures do
    it "passes a String through unchanged" do
      result = described_class.serialize(value: "hello")

      expect(result).to eq(
        value: "hello",
        value_type: "String",
        inspected: false,
        truncated: false
      )
    end

    it "truncates to MAX_LENGTH chars with a continuation marker" do
      long_string = "a" * (described_class::MAX_LENGTH + 523)

      result = described_class.serialize(value: long_string)

      expect(result[:value]).to eq("#{'a' * described_class::MAX_LENGTH} [+523 chars]")
      expect(result[:value_type]).to eq("String")
      expect(result[:inspected]).to be false
      expect(result[:truncated]).to be true
    end

    it "does not truncate a String at exactly MAX_LENGTH" do
      exact_length_string = "a" * described_class::MAX_LENGTH

      result = described_class.serialize(value: exact_length_string)

      expect(result[:value]).to eq(exact_length_string)
      expect(result[:truncated]).to be false
    end
  end

  describe ".handles?" do
    it "returns true for a String" do
      expect(described_class.handles?("hello")).to be true
    end

    it "returns false for a non-String" do
      expect(described_class.handles?(42)).to be false
    end
  end
end
