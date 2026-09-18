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
  end

  describe ".serialize when nesting depth is at or beyond MAX_DEPTH", :aggregate_failures do
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
  end

  describe ".serialize with an oversized Array", :aggregate_failures do
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
