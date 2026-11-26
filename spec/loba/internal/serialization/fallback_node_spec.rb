# Renders as the given text through both #inspect and #to_s.
class RenderedAs
  def initialize(text)
    @text = text
  end

  def inspect = @text

  def to_s = @text
end

RSpec.describe Loba::Internal::Serialization::FallbackNode do
  describe ".serialize", :aggregate_failures do
    def max_length = Loba::Internal::Text::Truncated::MAX_LENGTH

    it "falls back to #inspect for a value with no dedicated node type" do
      plain_object = object_with_distinct_inspect

      result = described_class.serialize(value: plain_object)

      expect(result[:value]).to eq(plain_object.inspect)
      expect(result[:value]).not_to eq(plain_object.to_s)
      expect(result[:value_type]).to eq("Object")
    end

    it "falls back to #to_s instead when use_inspect is false" do
      plain_object = object_with_distinct_inspect

      result = described_class.serialize(value: plain_object, use_inspect: false)

      expect(result[:value]).to eq(plain_object.to_s)
      expect(result[:value]).not_to eq(plain_object.inspect)
    end

    it "takes value_type from the class's own name" do
      self_named_class = Class.new(RenderedAs) { def self.name = "User" }

      result = described_class.serialize(value: self_named_class.new("text"))

      expect(result[:value_type]).to eq("User")
    end

    it "takes value_type from the class of a BasicObject, which has no #class" do
      stub_const("RenderedProxy", Class.new(BasicObject) { def inspect = "#<proxy>" })

      result = described_class.serialize(value: RenderedProxy.new)

      expect(result).to include(value: "#<proxy>", value_type: "RenderedProxy")
    end

    # The class's own name method is the traced program's code; value_type then
    # falls back to the class's constant name, as class_name does.
    context "when the class's own name can't be used" do
      it "uses the constant name when .name takes an argument" do
        stub_const("NameTakesArgument", Class.new(RenderedAs) { def self.name(_style) = "x" })

        result = described_class.serialize(value: NameTakesArgument.new("text"))

        expect(result).to include(value: "text", value_type: "NameTakesArgument")
      end

      it "uses the constant name when .name returns something other than a String" do
        stub_const("NameIsSymbol", Class.new(RenderedAs) { def self.name = :User })

        result = described_class.serialize(value: NameIsSymbol.new("text"))

        expect(result).to include(value: "text", value_type: "NameIsSymbol")
      end
    end

    # Long rendered text is cut exactly as a long String is.
    context "when the rendered text is longer than a String may be" do
      it "cuts #inspect output with the String marker, and lists the cut" do
        long_rendering = RenderedAs.new("a" * (max_length + 523))

        result = described_class.serialize(value: long_rendering)

        expect(result).to eq(
          value: "#{'a' * max_length} [+523 chars]",
          value_type: "RenderedAs",
          rendered: [{ path: [], as: "inspect" }],
          cut: [{ path: [], omitted: 523, unit: "chars" }]
        )
      end

      it "cuts #to_s output the same way" do
        long_rendering = RenderedAs.new("a" * (max_length + 523))

        result = described_class.serialize(value: long_rendering, use_inspect: false)

        expect(result[:value]).to eq("#{'a' * max_length} [+523 chars]")
      end
    end

    # Rendering runs the traced program's code, which can raise; the failure
    # is reported rather than raised.
    context "when the value can't be rendered" do
      it "marks it unrenderable and reports the error, without falling back to #to_s" do
        result = described_class.serialize(value: object_whose_inspect_raises)

        expect(result).to eq(
          value: "(unrenderable)", value_type: nil,
          errors: [{ path: [], message: "ArgumentError: boom" }]
        )
      end

      it "reports a #to_s that raises when use_inspect is false" do
        result = described_class.serialize(value: BasicObject.new, use_inspect: false)

        expect(result[:errors].first[:message])
          .to match(/\ANoMethodError: undefined method [`']to_s'/)
      end

      it "reports a BasicObject, which has no #inspect" do
        result = described_class.serialize(value: BasicObject.new)

        expect(result[:errors].first[:message])
          .to match(/\ANoMethodError: undefined method [`']inspect'/)
      end

      it "reports an error whose class name and message are in clashing encodings" do
        error_class = Class.new(StandardError) { def self.to_s = "Érror" }
        unrenderable = Object.new
        unrenderable.define_singleton_method(:inspect) { raise error_class, "bad \xFF".b }

        result = described_class.serialize(value: unrenderable)

        expect(result).to eq(
          value: "(unrenderable)", value_type: nil,
          errors: [{ path: [], message: "Érror: bad \uFFFD" }]
        )
      end
    end

    context "when rendering returns something other than a String" do
      it "marks it unrenderable and reports what #inspect returned" do
        result = described_class.serialize(value: RenderedAs.new(nil))

        expect(result).to eq(
          value: "(unrenderable)", value_type: nil,
          errors: [{ path: [], message: "TypeError: #inspect returned NilClass, not a String" }]
        )
      end

      it "reports what #to_s returned when use_inspect is false" do
        result = described_class.serialize(value: RenderedAs.new(:text), use_inspect: false)

        expect(result[:errors])
          .to eq([{ path: [], message: "TypeError: #to_s returned Symbol, not a String" }])
      end

      it "names the class of a returned BasicObject, which has no #class" do
        result = described_class.serialize(value: RenderedAs.new(BasicObject.new))

        expect(result[:errors].first[:message])
          .to eq("TypeError: #inspect returned BasicObject, not a String")
      end
    end
  end
end
