RSpec.describe Loba::Internal::Serialization::SymbolNode do
  describe ".serialize" do
    it "serializes a Symbol as itself" do
      expect(described_class.serialize(value: :total)).to eq(value: :total, value_type: "Symbol")
    end

    it "serializes a Symbol in another encoding as itself, since JSON converts it" do
      symbol = "café".encode(Encoding::ISO_8859_1).to_sym

      expect(described_class.serialize(value: symbol)).to eq(value: symbol, value_type: "Symbol")
    end

    context "when the Symbol is binary data" do
      it "records its #inspect text, and says why" do
        expect(described_class.serialize(value: "k\xFF".b.to_sym)).to eq(
          value: ":\"k\\xFF\"",
          value_type: "Symbol",
          rendered: [{ path: [], as: "not_utf8" }]
        )
      end

      it "cuts long text as a String's is" do
        max_length = Loba::Internal::Serialization::StringNode::MAX_LENGTH
        symbol = "#{'k' * max_length}\xFF".b.to_sym

        expect(described_class.serialize(value: symbol)[:cut])
          .to eq([{ path: [], omitted: 7, unit: "chars" }])
      end
    end
  end
end
