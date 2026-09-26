# Renders as the given text through both #inspect and #to_s.
class RenderedAs
  def initialize(text)
    @text = text
  end

  def inspect = @text

  def to_s = @text
end

RSpec.describe Lba::Internal::Serialization::FallbackNode do
  describe ".serialize", :aggregate_failures do
    def max_length = Lba::Internal::Serialization::StringNode::MAX_LENGTH

    it "falls back to #inspect for a value with no dedicated node type" do
      plain_object = object_with_distinct_inspect

      result = described_class.serialize(value: plain_object)

      expect(result[:value]).to eq(plain_object.inspect)
      expect(result[:value]).not_to eq(plain_object.to_s)
      expect(result[:value_type]).to eq("Object")
      expect(result[:inspected]).to be true
      expect(result[:truncated]).to be false
    end

    it "falls back to #to_s instead when use_inspect is false" do
      plain_object = object_with_distinct_inspect

      result = described_class.serialize(value: plain_object, use_inspect: false)

      expect(result[:value]).to eq(plain_object.to_s)
      expect(result[:value]).not_to eq(plain_object.inspect)
      expect(result[:inspected]).to be true
    end

    # Long rendered text is cut exactly as a long String is.
    context "when the rendered text is longer than a String may be" do
      it "cuts #inspect output with the String marker and flags it truncated" do
        long_rendering = RenderedAs.new("a" * (max_length + 523))

        result = described_class.serialize(value: long_rendering)

        expect(result).to eq(
          value: "#{'a' * max_length} [+523 chars]",
          value_type: "RenderedAs",
          inspected: true,
          truncated: true
        )
      end

      it "cuts #to_s output the same way" do
        long_rendering = RenderedAs.new("a" * (max_length + 523))

        result = described_class.serialize(value: long_rendering, use_inspect: false)

        expect(result[:value]).to eq("#{'a' * max_length} [+523 chars]")
        expect(result[:truncated]).to be true
      end
    end

    context "when the rendered text is exactly as long as a String may be" do
      it "leaves it whole" do
        exact_rendering = RenderedAs.new("a" * max_length)

        result = described_class.serialize(value: exact_rendering)

        expect(result[:value]).to eq("a" * max_length)
        expect(result[:truncated]).to be false
      end
    end
  end
end
