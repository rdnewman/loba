RSpec.describe Lba::Internal::Serialization::ArrayNode do
  describe ".serialize", :aggregate_failures do
    it "returns its entries' serialized values in order, as an Array" do
      plain_object = Object.new

      result = described_class.serialize(value: [1, plain_object, "two"])

      expect(result[:value]).to eq([1, plain_object.inspect, "two"])
      expect(result[:value_type]).to eq("Array")
    end

    context "when it has more than MAX_ENTRIES entries" do
      it "keeps the first MAX_ENTRIES, and :cut counts the rest" do
        entries = Array.new(described_class::MAX_ENTRIES + 7) { |i| i }

        result = described_class.serialize(value: entries)

        kept = (0...described_class::MAX_ENTRIES).to_a
        expect(result[:value]).to eq(kept)
        expect(result[:cut]).to eq([{ path: [], omitted: 7, unit: "entries" }])
      end
    end

    context "when an entry can't be rendered" do
      it "keeps the other entries and reports the failure by index" do
        result = described_class.serialize(value: [1, object_whose_inspect_raises, 3])

        expect(result).to eq(
          value: [1, "(unrenderable)", 3], value_type: "Array",
          errors: [{ path: [1], message: "ArgumentError: boom" }]
        )
      end

      it "reports a failure nested deeper by its full path" do
        result = described_class.serialize(value: [[0, object_whose_inspect_raises]])

        expect(result[:errors]).to eq([{ path: [0, 1], message: "ArgumentError: boom" }])
      end
    end

    it "reports no errors key when every entry renders" do
      result = described_class.serialize(value: [1, 2])

      expect(result).not_to have_key(:errors)
    end
  end
end
