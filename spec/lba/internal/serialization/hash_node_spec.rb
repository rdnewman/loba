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
      it "serializes the key too, and a cut key makes the Hash truncated" do
        plain_object = Object.new

        result = described_class.serialize(value: { plain_object => 1, oversized_string => 2 })

        truncated_key = oversized_string[0, Lba::Internal::Serialization::StringNode::MAX_LENGTH]
        expect(result[:value].keys)
          .to match([plain_object.inspect, a_string_starting_with(truncated_key)])
        expect(result).to include(truncated: true)
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

    context "when a value can't be rendered" do
      it "keeps the other pairs and reports the failure by key, as JSON writes the key" do
        result = described_class.serialize(value: { ok: 1, broken: object_whose_inspect_raises })

        expect(result).to eq(
          value: { ok: 1, broken: "(unrenderable)" }, value_type: "Hash",
          truncated: false,
          errors: [{ path: ["broken"], message: "ArgumentError: boom" }]
        )
      end
    end

    # Keys that JSON writes as the same text would leave duplicate JSON keys,
    # and a JSON parser keeps only one of them: a pair would vanish with no
    # trace. The first pair stays in the value; :collided lists every pair as
    # #inspect text, which also shows why they collided (a Symbol and a
    # String, say).
    context "when keys collide" do
      it "keeps the first pair, and lists every colliding pair" do
        result = described_class.serialize(value: { 1 => "int", "1" => "str" })

        expect(result[:value]).to eq(1 => "int")
        expect(result[:collided])
          .to eq([{ path: [], key: "1", pairs: [["1", "\"int\""], ["\"1\"", "\"str\""]] }])
      end

      it "shows a Symbol and a String key apart" do
        result = described_class.serialize(value: { a: "sym", "a" => "str" })

        expect(result[:collided].first[:pairs]).to eq([[":a", "\"sym\""], ["\"a\"", "\"str\""]])
      end

      it "lists three or more colliding keys as one entry" do
        result = described_class.serialize(value: { 1 => "x", "1" => "y", "1": "z" })

        expect(result[:collided].map { _1[:pairs].size }).to eq([3])
      end

      it "gives the colliding Hash's path when it's nested" do
        result = described_class.serialize(value: { outer: { 1 => "x", "1" => "y" } })

        expect(result[:collided].map { _1[:path] }).to eq([["outer"]])
      end

      it "is absent when no keys collide" do
        result = described_class.serialize(value: { 1 => "x", "2" => "y" })

        expect(result).not_to have_key(:collided)
      end

      # The pairs are #inspect text even with inspect: false: #to_s would show
      # :a and "a" alike, hiding why they collided.
      it "uses #inspect for the pairs, whatever inspect: says" do
        result = described_class.serialize(value: { a: 1, "a" => 2 }, use_inspect: false)

        expect(result[:collided].first[:pairs].map(&:first)).to eq([":a", "\"a\""])
      end

      it "cuts long pair text like a long String" do
        long = "z" * (Lba::Internal::Serialization::StringNode::MAX_LENGTH + 10)

        result = described_class.serialize(value: { 1 => "x", "1" => long })

        expect(result[:collided].first[:pairs].last.last).to end_with(" [+12 chars]")
      end

      # A part of a lost pair has no place in the value, so a path to it
      # would point at the kept pair instead.
      it "reports nothing found inside a lost pair in rendered or errors" do
        result = described_class.serialize(value: { 1 => "x", "1" => object_whose_inspect_raises })

        expect(result).not_to include(:rendered, :errors)
      end

      it "isn't truncated by a lost pair, since the value holds none of it" do
        long = "z" * (Lba::Internal::Serialization::StringNode::MAX_LENGTH + 10)

        result = described_class.serialize(value: { 1 => "x", "1" => long })

        expect(result[:truncated]).to be false
      end

      it "shows a lost pair whose #inspect raises as unrenderable text" do
        result = described_class.serialize(value: { 1 => "x", "1" => object_whose_inspect_raises })

        expect(result[:collided].first[:pairs].last).to eq(["\"1\"", "(unrenderable)"])
      end
    end

    context "when a key can't be rendered" do
      it "reports the failure at the pair's path, marked key: true" do
        result = described_class.serialize(value: { object_whose_inspect_raises => 1 })

        expect(result[:errors])
          .to eq([{ path: ["(unrenderable)"], message: "ArgumentError: boom", key: true }])
      end
    end
  end
end
