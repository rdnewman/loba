RSpec.describe Lba::Internal::Serialization do
  describe ".serialize", :aggregate_failures do
    it "serializes a native value as itself, with its type" do
      result = described_class.serialize(value: 42)

      expect(result).to eq(
        value: 42,
        value_type: "Integer",
        truncated: false
      )
    end

    context "when a value has no native JSON form" do
      it "renames the public inspect: kwarg through to the fallback's #to_s choice" do
        plain_object = object_with_distinct_inspect

        result = described_class.serialize(value: plain_object, inspect: false)

        expect(result[:value]).to eq(plain_object.to_s)
        expect(result[:value]).not_to eq(plain_object.inspect)
      end

      it "still uses #inspect by default" do
        plain_object = object_with_distinct_inspect

        result = described_class.serialize(value: plain_object)

        expect(result[:value]).to eq(plain_object.inspect)
      end
    end

    context "when given a realistic mixed structure" do
      # rubocop:disable-next RSpec/ExampleLength -- a realistic tree needs its
      # full input and output side by side.
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
        expect(result[:truncated]).to be false
      end
    end

    context "when a nested value is truncated" do
      it "propagates truncated: true up through nested Array/Hash from an oversized String" do
        long_string = "a" * (Lba::Internal::Serialization::StringNode::MAX_LENGTH + 10)
        input = { list: [1, long_string] }

        result = described_class.serialize(value: input)

        expected_string =
          "#{'a' * Lba::Internal::Serialization::StringNode::MAX_LENGTH} [+10 chars]"
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
        long_hash =
          (0...(Lba::Internal::Serialization::HashNode::MAX_ENTRIES + 2)).to_h { |i| [i, i] }
        input = [1, long_hash]

        result = described_class.serialize(value: input)

        expect(result[:value][1]["[+2 more keys]"]).to be true
        expect(result[:truncated]).to be true
      end
    end

    context "when Hash and Array nesting alternate" do
      # The wrap type alternates by distance from the root, so a shallower
      # slice, as in the boundary test below, matches the deeper original.
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
        expect(result[:value]).to eq(just_fits)
      end

      it "falls back to #inspect one level past MAX_DEPTH across alternating Hash/Array nesting" do
        max_depth = Lba::Internal::Serialization::HashNode::MAX_DEPTH
        too_deep = nested_mixed(max_depth + 1)
        collapsed = nested_mixed(1, depth_from_root: max_depth)

        result = described_class.serialize(value: too_deep)
        expect(result[:value]).to eq(nested_mixed(max_depth, leaf: collapsed.inspect))
      end
    end

    # A failure is always reported in :errors; :value is kept when part of the
    # value could still be recorded.
    context "when the value can't be rendered" do
      it "reports only the errors, for the whole value" do
        result = described_class.serialize(value: object_whose_inspect_raises)

        expect(result).to eq(errors: [{ path: [], message: "ArgumentError: boom" }])
      end
    end

    context "when part of the value can't be rendered" do
      it "keeps the rest of the value and reports each failure by path" do
        bad = object_whose_inspect_raises

        result = described_class.serialize(value: { "items" => [bad, 1, bad] })

        expect(result).to eq(
          value: { "items" => ["(unrenderable)", 1, "(unrenderable)"] }, value_type: "Hash",
          truncated: false,
          errors: [
            { path: ["items", 0], message: "ArgumentError: boom" },
            { path: ["items", 2], message: "ArgumentError: boom" }
          ]
        )
      end
    end
  end
end
