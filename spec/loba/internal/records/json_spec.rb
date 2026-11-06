RSpec.describe Loba::Internal::Records::Json do
  describe ".generate" do
    it "writes a record as JSON" do
      expect(described_class.generate({ seq: 1, label: "café" })).to eq('{"seq":1,"label":"café"}')
    end

    context "when text in the record isn't valid UTF-8" do
      it "replaces the bytes that aren't, in a binary String" do
        expect(described_class.generate({ text: "café \xFF".b })).to eq('{"text":"café �"}')
      end

      it "replaces the bytes that aren't, in a String claiming to be UTF-8" do
        expect(described_class.generate({ text: "bad \xFF" })).to eq('{"text":"bad �"}')
      end

      it "replaces them in a Symbol" do
        expect(described_class.generate({ text: "bad \xFF".b.to_sym })).to eq('{"text":"bad �"}')
      end

      it "replaces them in a key" do
        expect(described_class.generate({ "bad \xFF".b => 1 })).to eq('{"bad �":1}')
      end

      it "replaces them inside nested Arrays and Hashes" do
        record = { items: [{ text: "bad \xFF".b }] }

        expect(described_class.generate(record)).to eq('{"items":[{"text":"bad �"}]}')
      end

      it "leaves everything else in the record as it was" do
        record = { seq: 1, on: true, none: nil, at: 1.5, ok: "café", bad: "\xFF".b }

        expect(described_class.generate(record))
          .to eq('{"seq":1,"on":true,"none":null,"at":1.5,"ok":"café","bad":"�"}')
      end
    end

    it "raises for a record JSON can't write, whatever its text" do
      expect { described_class.generate({ ratio: Float::NAN, bad: "\xFF".b }) }
        .to raise_error(JSON::GeneratorError)
    end
  end
end
