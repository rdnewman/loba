# Long Strings and big containers are cut short. :cut names each cut part by
# its path and says how much was left out, so a reader can tell a cut value
# from a complete one without relying on a marker inside the data.
RSpec.describe Loba::Internal::Serialization do
  describe ".serialize :cut" do
    def max_length = Loba::Internal::Serialization::StringNode::MAX_LENGTH
    def max_entries = Loba::Internal::Serialization::ContainerNode::MAX_ENTRIES

    def cut(value)
      described_class.serialize(value:)[:cut]
    end

    it "is absent when nothing was cut" do
      result = described_class.serialize(value: { "body" => "short", "items" => [1, 2] })

      expect(result).not_to have_key(:cut)
    end

    describe "how much was left out" do
      it "counts chars for a long String, which keeps its marker", :aggregate_failures do
        result = described_class.serialize(value: "a" * (max_length + 10))

        expect(result[:cut]).to eq([{ path: [], omitted: 10, unit: "chars" }])
        expect(result[:value]).to end_with(" [+10 chars]")
      end

      it "counts entries for a big Array, with no marker entry", :aggregate_failures do
        result = described_class.serialize(value: Array.new(max_entries + 3) { _1 })

        expect(result[:cut]).to eq([{ path: [], omitted: 3, unit: "entries" }])
        expect(result[:value]).to eq(Array.new(max_entries) { _1 })
      end

      it "counts keys for a big Hash, with no marker key", :aggregate_failures do
        big = Array.new(max_entries + 2) { ["k#{_1}", _1] }.to_h

        result = described_class.serialize(value: big)

        expect(result[:cut]).to eq([{ path: [], omitted: 2, unit: "keys" }])
        expect(result[:value].keys).to eq(big.keys.first(max_entries))
      end

      it "counts chars for long text rendered from an object" do
        text = "z" * (max_length + 4)
        long_rendering = Object.new
        long_rendering.define_singleton_method(:inspect) { text }

        expect(cut(long_rendering)).to eq([{ path: [], omitted: 4, unit: "chars" }])
      end
    end

    describe "where a part is" do
      it "is its key, as JSON writes it, in a Hash" do
        expect(cut({ body: "a" * (max_length + 1) }))
          .to eq([{ path: ["body"], omitted: 1, unit: "chars" }])
      end

      it "is the pair's path, marked key: true, for a key" do
        long_key = "k" * (max_length + 2)
        cut_key = "#{'k' * max_length} [+2 chars]"

        expect(cut({ long_key => 1 }))
          .to eq([{ path: [cut_key], omitted: 2, unit: "chars", key: true }])
      end
    end

    it "lists every cut part, in order" do
      value = ["a" * (max_length + 1), Array.new(max_entries + 1, 0)]

      expect(cut(value)).to eq(
        [{ path: [0], omitted: 1, unit: "chars" }, { path: [1], omitted: 1, unit: "entries" }]
      )
    end
  end
end
