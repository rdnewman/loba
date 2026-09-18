RSpec.describe Lba::Internal::Serialization do
  describe ".serialize" do
    it "delegates to UnknownNode" do
      result = described_class.serialize(value: 42)

      expect(result).to eq(
        value: 42,
        value_type: "Integer",
        inspected: false,
        truncated: false
      )
    end
  end

  describe ".serialize with a realistic mixed structure", :aggregate_failures do
    # rubocop:disable-next RSpec/ExampleLength -- a realistic mixed tree needs a
    # correspondingly real input/output pair; splitting it up would obscure it.
    it "serializes a Hash/Array/String/native/plain-object mix end-to-end" do
      plain_object = Object.new

      input = {
        name: "trace",
        count: 3,
        tags: [:a, "b", 3, plain_object],
        meta: { nested: true, deep: { value: 1 } }
      }

      result = described_class.serialize(value: input)

      expect(result[:value]).to eq(
        name: "trace",
        count: 3,
        tags: [:a, "b", 3, plain_object.inspect],
        meta: { nested: true, deep: { value: 1 } }
      )
      expect(result[:value_type]).to eq("Hash")
      expect(result[:inspected]).to be true
      expect(result[:truncated]).to be false
    end

    it "propagates truncated: true up through nested Array/Hash from an oversized String" do
      long_string = "a" * (Lba::Internal::Serialization::StringNode::MAX_LENGTH + 10)
      input = { list: [1, long_string] }

      result = described_class.serialize(value: input)

      expected_string = "#{'a' * Lba::Internal::Serialization::StringNode::MAX_LENGTH} [+10 chars]"
      expect(result[:value]).to eq(list: [1, expected_string])
      expect(result[:truncated]).to be true
    end

    it "propagates truncated: true up through a Hash from an oversized nested Array" do
      long_array = Array.new(Lba::Internal::Serialization::ArrayNode::MAX_ENTRIES + 3) { |i| i }
      input = { list: long_array }

      result = described_class.serialize(value: input)

      expect(result[:value][:list].last).to eq("[+3 more entries]")
      expect(result[:truncated]).to be true
    end

    it "propagates truncated: true up through an Array from an oversized nested Hash" do
      long_hash = (0...(Lba::Internal::Serialization::HashNode::MAX_ENTRIES + 2)).to_h { |i| [i, i] }
      input = [1, long_hash]

      result = described_class.serialize(value: input)

      expect(result[:value][1]["[+2 more keys]"]).to be true
      expect(result[:truncated]).to be true
    end
  end

  describe ".serialize with nested Hash/Array combinations", :aggregate_failures do
    # Wrap type alternates by absolute position from the root (not by the
    # remaining count), so reconstructing a shallower slice of the same
    # structure -- as the boundary test below does -- lines up with what
    # the original deeper call actually produced at that position.
    def nested_mixed(levels, depth_from_root: 0, leaf: "leaf")
      return leaf if levels.zero?

      inner = nested_mixed(levels - 1, depth_from_root: depth_from_root + 1, leaf:)

      if depth_from_root.even?
        { a: inner }
      else
        [inner]
      end
    end

    it "recurses fully through exactly MAX_DEPTH levels across alternating Hash/Array nesting" do
      just_fits = nested_mixed(Lba::Internal::Serialization::HashNode::MAX_DEPTH)

      result = described_class.serialize(value: just_fits)

      expect(result[:inspected]).to be false
      expect(result[:value]).to eq(just_fits)
    end

    it "falls back to #inspect one level past MAX_DEPTH across alternating Hash/Array nesting" do
      max_depth = Lba::Internal::Serialization::HashNode::MAX_DEPTH
      too_deep = nested_mixed(max_depth + 1)
      collapsed = nested_mixed(1, depth_from_root: max_depth)

      result = described_class.serialize(value: too_deep)

      expect(result[:inspected]).to be true
      expect(result[:value]).to eq(nested_mixed(max_depth, leaf: collapsed.inspect))
    end
  end
end
