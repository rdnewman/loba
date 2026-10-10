RSpec.describe Lba::Internal::Serialization::StringNode do
  describe ".serialize", :aggregate_failures do
    it "passes a String through unchanged" do
      result = described_class.serialize(value: "hello")

      expect(result).to eq(
        value: "hello",
        value_type: "String",
        inspected: false,
        truncated: false
      )
    end

    it "truncates to MAX_LENGTH chars with a continuation marker" do
      long_string = "a" * (described_class::MAX_LENGTH + 523)

      result = described_class.serialize(value: long_string)

      expect(result[:value]).to eq("#{'a' * described_class::MAX_LENGTH} [+523 chars]")
      expect(result[:value_type]).to eq("String")
      expect(result[:inspected]).to be false
      expect(result[:truncated]).to be true
    end

    it "does not truncate a String at exactly MAX_LENGTH" do
      exact_length_string = "a" * described_class::MAX_LENGTH

      result = described_class.serialize(value: exact_length_string)

      expect(result[:value]).to eq(exact_length_string)
      expect(result[:truncated]).to be false
    end

    # JSON text is UTF-8, so a String is recorded as-is only if it is UTF-8 or
    # converts to it; anything else is recorded as its #inspect text.
    context "when the String is in another encoding that converts to UTF-8" do
      it "records it converted to UTF-8" do
        latin1 = "café".encode(Encoding::ISO_8859_1)

        result = described_class.serialize(value: latin1)

        expect(result).to eq(
          value: "café", value_type: "String", inspected: false, truncated: false
        )
        expect(result[:value].encoding).to eq(Encoding::UTF_8)
      end
    end

    context "when the String holds bytes that aren't valid text" do
      it "records binary data as its #inspect text" do
        binary = "\xFF\xFE".b

        result = described_class.serialize(value: binary)

        expect(result).to eq(
          value: "\"\\xFF\\xFE\"", value_type: "String", inspected: true, truncated: false
        )
      end

      it "records invalid UTF-8 as its #inspect text" do
        invalid = String.new("ok\xFF", encoding: Encoding::UTF_8)

        result = described_class.serialize(value: invalid)

        expect(result).to eq(
          value: "\"ok\\xFF\"", value_type: "String", inspected: true, truncated: false
        )
      end

      it "cuts long #inspect text like any long String" do
        long_binary = ("\xFF" * described_class::MAX_LENGTH).b

        result = described_class.serialize(value: long_binary)

        expect(result).to include(inspected: true, truncated: true)
        expect(result[:value]).to end_with(" chars]")
      end
    end
  end
end
