RSpec.describe Lba::Internal::Serialization::HashNode do
  describe ".serialize", :aggregate_failures do
    def oversized_string
      "a" * (Lba::Internal::Serialization::StringNode::MAX_LENGTH + 1)
    end

    it "returns its pairs with each value serialized, as a Hash" do
      plain_object = Object.new

      result = described_class.serialize(value: { a: 1, b: plain_object })

      expect(result[:value]).to eq(a: 1, b: plain_object.inspect)
      expect(result[:value_type]).to eq("Hash")
    end

    context "when a key needs serializing" do
      it "serializes the key too, and its flags count toward the Hash's" do
        plain_object = Object.new

        result = described_class.serialize(value: { plain_object => 1, oversized_string => 2 })

        truncated_key = oversized_string[0, Lba::Internal::Serialization::StringNode::MAX_LENGTH]
        expect(result[:value].keys)
          .to match([plain_object.inspect, a_string_starting_with(truncated_key)])
        expect(result).to include(inspected: true, truncated: true)
      end
    end

    # A key and its value sit one level below the Hash; the pair between
    # them is not a level of its own.
    context "when a value is itself a container" do
      it "counts it one level deeper than the Hash" do
        max_depth = described_class::MAX_DEPTH

        within_limit = described_class.serialize(value: { a: [1] }, depth: max_depth - 2)
        at_limit = described_class.serialize(value: { a: [1] }, depth: max_depth - 1)

        expect(within_limit[:value]).to eq(a: [1])
        expect(at_limit[:value]).to eq(a: "[1]")
      end
    end

    context "when it has more than MAX_ENTRIES pairs" do
      it "keeps the first MAX_ENTRIES and adds a key counting the rest" do
        pairs = (0...(described_class::MAX_ENTRIES + 7)).to_h { |i| [i, i] }

        result = described_class.serialize(value: pairs)

        kept = (0...described_class::MAX_ENTRIES).to_h { |i| [i, i] }
        expect(result[:value]).to eq(kept.merge("[+7 more keys]" => true))
      end
    end
  end
end
