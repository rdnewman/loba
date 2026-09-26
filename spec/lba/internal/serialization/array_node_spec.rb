RSpec.describe Lba::Internal::Serialization::ArrayNode do
  describe ".serialize", :aggregate_failures do
    it "passes an Array of native values through unchanged" do
      result = described_class.serialize(value: [1, "two", true])

      expect(result[:value]).to eq([1, "two", true])
      expect(result[:value_type]).to eq("Array")
      expect(result[:inspected]).to be false
      expect(result[:truncated]).to be false
    end

    it "recursively substitutes a non-native entry and aggregates inspected: true" do
      plain_object = Object.new

      result = described_class.serialize(value: [1, plain_object])

      expect(result[:value]).to eq([1, plain_object.inspect])
      expect(result[:inspected]).to be true
      expect(result[:truncated]).to be false
    end

    # A flag is true if any entry's is. Flags set early or on different
    # entries catch code that keeps only the last entry's value.
    context "when an entry other than the last is flagged" do
      def oversized_string
        "a" * (Lba::Internal::Serialization::StringNode::MAX_LENGTH + 1)
      end

      it "aggregates inspected: true when the non-native entry comes first" do
        result = described_class.serialize(value: [Object.new, 1])

        expect(result[:inspected]).to be true
      end

      it "aggregates truncated: true when the truncated entry comes first" do
        result = described_class.serialize(value: [oversized_string, 1])

        expect(result[:truncated]).to be true
      end

      it "aggregates inspected and truncated independently from different entries" do
        result = described_class.serialize(value: [Object.new, 1, oversized_string])

        expect(result[:inspected]).to be true
        expect(result[:truncated]).to be true
      end
    end

    context "when nesting depth is at or beyond MAX_DEPTH" do
      def nested_array(levels, leaf: "leaf")
        if levels.zero?
          leaf
        else
          [nested_array(levels - 1, leaf:)]
        end
      end

      it "recurses fully through exactly MAX_DEPTH levels of nesting" do
        just_fits = nested_array(described_class::MAX_DEPTH)

        result = described_class.serialize(value: just_fits)

        expect(result[:inspected]).to be false
        expect(result[:value]).to eq(just_fits)
      end

      it "falls back to #inspect for the container one level past MAX_DEPTH" do
        too_deep = nested_array(described_class::MAX_DEPTH + 1)

        result = described_class.serialize(value: too_deep)

        expect(result[:inspected]).to be true
        expect(result[:value]).to eq([[[[["[\"leaf\"]"]]]]])
      end

      it "terminates safely for a circular structure instead of recursing forever" do
        circular = []
        circular << circular

        result = described_class.serialize(value: circular)

        expect(result[:inspected]).to be true
        expect(result[:value]).to eq([[[[["[[...]]"]]]]])
      end

      it "forwards use_inspect to the cutoff fallback" do
        too_deep = nested_array(described_class::MAX_DEPTH + 1)
        inner = nested_array(1)
        allow(Lba::Internal::Serialization::FallbackNode).to receive(:serialize).and_call_original

        described_class.serialize(value: too_deep, use_inspect: false)

        expect(Lba::Internal::Serialization::FallbackNode).to have_received(:serialize).with(
          value: inner, depth: described_class::MAX_DEPTH, use_inspect: false
        )
      end
    end

    context "when the Array's size is at or above MAX_ENTRIES" do
      it "truncates to MAX_ENTRIES elements with a continuation marker" do
        long_array = Array.new(described_class::MAX_ENTRIES + 7) { |i| i }

        result = described_class.serialize(value: long_array)

        expected_value = (0...described_class::MAX_ENTRIES).to_a + ["[+7 more entries]"]
        expect(result[:value]).to eq(expected_value)
        expect(result[:value_type]).to eq("Array")
        expect(result[:inspected]).to be false
        expect(result[:truncated]).to be true
      end

      it "does not truncate an Array at exactly MAX_ENTRIES" do
        exact_size_array = Array.new(described_class::MAX_ENTRIES) { |i| i }

        result = described_class.serialize(value: exact_size_array)

        expect(result[:value]).to eq(exact_size_array)
        expect(result[:truncated]).to be false
      end
    end
  end
end
