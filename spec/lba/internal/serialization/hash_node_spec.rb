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
  end

  describe ".serialize when nesting depth is at or beyond MAX_DEPTH", :aggregate_failures do
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
      expect(result[:value]).to eq(nested_hash(described_class::MAX_DEPTH, leaf: collapsed.inspect))
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
  end

  describe ".serialize with an oversized Hash", :aggregate_failures do
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
