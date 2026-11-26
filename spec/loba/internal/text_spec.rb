RSpec.describe Loba::Internal::Text do
  describe ".make_utf8" do
    it "reads a binary String's bytes as UTF-8, replacing those that aren't" do
      expect(described_class.make_utf8("café \xFF".b)).to eq("café \uFFFD")
    end

    it "replaces the invalid bytes in a String claiming to be UTF-8" do
      expect(described_class.make_utf8("bad \xFF")).to eq("bad \uFFFD")
    end

    it "converts a String in another encoding" do
      expect(described_class.make_utf8("café".encode(Encoding::ISO_8859_1))).to eq("café")
    end

    it "reads the bytes as UTF-8 for an encoding Ruby can't convert from, such as UTF-7" do
      text = "caf\xC3\xA9 \xFF".b.force_encoding(Encoding::UTF_7)

      expect(described_class.make_utf8(text)).to eq("café \uFFFD")
    end

    it "returns valid UTF-8 for a String in any encoding Ruby knows" do
      results = Encoding.list.map do |encoding|
        described_class.make_utf8("caf\xC3\xA9 \xFF".b.force_encoding(encoding))
      end

      expect(results).to all(
        satisfy { |result| result.encoding == Encoding::UTF_8 && result.valid_encoding? }
      )
    end
  end

  describe ".of_error" do
    def error_class(name, &body)
      Class.new(StandardError) do
        define_singleton_method(:to_s) { name }
        class_eval(&body) if body
      end
    end

    it "is the class and message" do
      expect(described_class.of_error(ArgumentError.new("boom"))).to eq("ArgumentError: boom")
    end

    it "makes each part valid, so a binary message can join a non-ASCII class name" do
      error = error_class("Érror").new("bad \xFF".b)

      expect(described_class.of_error(error)).to eq("Érror: bad \uFFFD")
    end

    it "makes each part valid, so a non-ASCII message can join a binary class name" do
      error = error_class("E\xFF".b).new("café")

      expect(described_class.of_error(error)).to eq("E\uFFFD: café")
    end

    it "stands in for a message that raises" do
      error = error_class("ReportError") { def message = raise(ArgumentError, "no message") }.new

      expect(described_class.of_error(error)).to eq("ReportError: (unreadable message)")
    end

    it "leaves the message empty when it is nil" do
      error = error_class("ReportError") { def message = nil }.new

      expect(described_class.of_error(error)).to eq("ReportError: ")
    end

    # The error's class is the traced program's, and so is its own to_s.
    context "when the error class's own to_s can't be used" do
      it "uses the class's constant name when to_s raises" do
        stub_const("UnnameableError", Class.new(StandardError) { def self.to_s = raise("no name") })

        expect(described_class.of_error(UnnameableError.new("boom"))).to eq("UnnameableError: boom")
      end

      it "uses the class's constant name when to_s returns something other than a String" do
        stub_const("SymbolNamedError", Class.new(StandardError) { def self.to_s = :name })

        expect(described_class.of_error(SymbolNamedError.new("boom")))
          .to eq("SymbolNamedError: boom")
      end
    end
  end
end
