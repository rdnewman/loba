RSpec.describe Lba::Internal::Serialization::ArrayNode do
  describe ".serialize", :aggregate_failures do
    it "returns its entries' serialized values in order, as an Array" do
      plain_object = Object.new

      result = described_class.serialize(value: [1, plain_object, "two"])

      expect(result[:value]).to eq([1, plain_object.inspect, "two"])
      expect(result[:value_type]).to eq("Array")
    end

    context "when it has more than MAX_ENTRIES entries" do
      it "keeps the first MAX_ENTRIES and appends a count of the rest" do
        entries = Array.new(described_class::MAX_ENTRIES + 7) { |i| i }

        result = described_class.serialize(value: entries)

        kept = (0...described_class::MAX_ENTRIES).to_a
        expect(result[:value]).to eq(kept + ["[+7 more entries]"])
      end
    end
  end
end
