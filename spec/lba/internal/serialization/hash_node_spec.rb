RSpec.describe Lba::Internal::Serialization::HashNode do
  describe ".serialize", :aggregate_failures do
    it "passes a Hash of native values through unchanged" do
      result = described_class.serialize(value: { a: 1, b: "two" })

      expect(result[:value]).to eq(a: 1, b: "two")
      expect(result[:value_type]).to eq("Hash")
      expect(result[:inspected]).to be false
      expect(result[:truncated]).to be false
    end

    it "recursively substitutes a non-native value and aggregates inspected: true" do
      plain_object = Object.new

      result = described_class.serialize(value: { a: 1, b: plain_object })

      expect(result[:value]).to eq(a: 1, b: plain_object.inspect)
      expect(result[:inspected]).to be true
      expect(result[:truncated]).to be false
    end

    it "recursively substitutes a non-native key and aggregates inspected: true" do
      plain_object = Object.new

      result = described_class.serialize(value: { plain_object => 1 })

      expect(result[:value]).to eq(plain_object.inspect => 1)
      expect(result[:inspected]).to be true
      expect(result[:truncated]).to be false
    end

    # A flag is true if any pair's is. Flags set early or on different pairs
    # catch code that keeps only the last pair's value.
    context "when a pair other than the last is flagged" do
      def oversized_string
        "a" * (Lba::Internal::Serialization::StringNode::MAX_LENGTH + 1)
      end

      it "aggregates inspected: true when the non-native pair comes first" do
        result = described_class.serialize(value: { a: Object.new, b: 1 })

        expect(result[:inspected]).to be true
      end

      it "aggregates truncated: true when the truncated pair comes first" do
        result = described_class.serialize(value: { a: oversized_string, b: 1 })

        expect(result[:truncated]).to be true
      end

      it "aggregates inspected and truncated independently from different pairs" do
        result = described_class.serialize(value: { a: Object.new, b: 1, c: oversized_string })

        expect(result[:inspected]).to be true
        expect(result[:truncated]).to be true
      end
    end

    context "when nesting depth is at or beyond MAX_DEPTH" do
      def nested_hash(levels, leaf: "leaf")
        if levels.zero?
          leaf
        else
          { a: nested_hash(levels - 1, leaf:) }
        end
      end

      it "recurses fully through exactly MAX_DEPTH levels of nesting" do
        just_fits = nested_hash(described_class::MAX_DEPTH)

        result = described_class.serialize(value: just_fits)

        expect(result[:inspected]).to be false
        expect(result[:value]).to eq(just_fits)
      end

      it "falls back to #inspect for the container one level past MAX_DEPTH" do
        too_deep = nested_hash(described_class::MAX_DEPTH + 1)
        collapsed = nested_hash(1)

        result = described_class.serialize(value: too_deep)

        expect(result[:inspected]).to be true
        expect(result[:value]).to eq(
          nested_hash(described_class::MAX_DEPTH, leaf: collapsed.inspect)
        )
      end

      it "terminates safely for a circular structure instead of recursing forever" do
        circular = {}
        circular[:self] = circular

        result = described_class.serialize(value: circular)

        expect(result[:inspected]).to be true
        expect(result[:value]).to eq(
          self: { self: { self: { self: { self: circular.inspect } } } }
        )
      end

      it "forwards use_inspect to the cutoff fallback" do
        too_deep = nested_hash(described_class::MAX_DEPTH + 1)
        inner = nested_hash(1)
        allow(Lba::Internal::Serialization::FallbackNode).to receive(:serialize).and_call_original

        described_class.serialize(value: too_deep, use_inspect: false)

        expect(Lba::Internal::Serialization::FallbackNode).to have_received(:serialize).with(
          value: inner, depth: described_class::MAX_DEPTH, use_inspect: false
        )
      end
    end

    context "when the Hash's size is at or above MAX_ENTRIES" do
      it "truncates to MAX_ENTRIES pairs with a continuation marker" do
        long_hash = (0...(described_class::MAX_ENTRIES + 7)).to_h { |i| [i, i] }

        result = described_class.serialize(value: long_hash)

        kept_pairs = (0...described_class::MAX_ENTRIES).to_h { |i| [i, i] }
        expected_value = kept_pairs.merge("[+7 more keys]" => true)

        expect(result[:value]).to eq(expected_value)
        expect(result[:value_type]).to eq("Hash")
        expect(result[:inspected]).to be false
        expect(result[:truncated]).to be true
      end

      it "does not truncate a Hash at exactly MAX_ENTRIES" do
        exact_size_hash = (0...described_class::MAX_ENTRIES).to_h { |i| [i, i] }

        result = described_class.serialize(value: exact_size_hash)

        expect(result[:value]).to eq(exact_size_hash)
        expect(result[:truncated]).to be false
      end
    end
  end
end
