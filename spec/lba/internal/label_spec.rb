RSpec.describe Lba::Internal::Label do
  describe ".infer" do
    context "when no explicit label is given" do
      it "infers the label from a Symbol argument" do
        result = described_class.infer(argument: :foo, label: nil)

        expect(result).to eq("foo")
      end

      it "returns nil when the argument is not a Symbol" do
        result = described_class.infer(argument: "some value", label: nil)

        expect(result).to be_nil
      end

      it "returns nil for a BasicObject argument, which has no #is_a?" do
        result = described_class.infer(argument: BasicObject.new, label: nil)

        expect(result).to be_nil
      end
    end

    context "when an explicit String label is given" do
      it "returns the label" do
        result = described_class.infer(argument: :foo, label: "My Label")

        expect(result).to eq("My Label")
      end

      it "strips surrounding whitespace" do
        result = described_class.infer(argument: :foo, label: "  My Label  ")

        expect(result).to eq("My Label")
      end
    end

    context "when an explicit String label isn't valid UTF-8" do
      it "replaces the invalid bytes with U+FFFD" do
        result = described_class.infer(argument: :foo, label: "a\xFFb")

        expect(result).to eq("a\u{FFFD}b")
      end

      it "reads a binary label's bytes as UTF-8 when they're valid there" do
        result = described_class.infer(argument: :foo, label: "caf\xC3\xA9".b)

        expect(result).to eq("café")
      end

      it "replaces a binary label's bytes with U+FFFD when they aren't valid UTF-8" do
        result = described_class.infer(argument: :foo, label: "a\xFFb".b)

        expect(result).to eq("a\u{FFFD}b")
      end

      it "converts a label in another encoding to UTF-8" do
        latin1_label = String.new("caf\xE9", encoding: Encoding::ISO_8859_1)

        result = described_class.infer(argument: :foo, label: latin1_label)

        expect(result).to eq("café")
      end

      it "strips surrounding whitespace" do
        result = described_class.infer(argument: :foo, label: "  a\xFFb  ")

        expect(result).to eq("a\u{FFFD}b")
      end
    end

    context "when an explicit Symbol label is given" do
      it "coerces it to a String" do
        result = described_class.infer(argument: :foo, label: :custom)

        expect(result).to eq("custom")
      end

      it "strips surrounding whitespace" do
        result = described_class.infer(argument: :foo, label: :" custom ")

        expect(result).to eq("custom")
      end
    end

    context "when the explicit label is neither a String nor a Symbol" do
      it "returns nil rather than raising" do
        result = described_class.infer(argument: :foo, label: {})

        expect(result).to be_nil
      end

      it "does not fall back to inferring from the Symbol argument" do
        result = described_class.infer(argument: :foo, label: 42)

        expect(result).to be_nil
      end
    end
  end
end
