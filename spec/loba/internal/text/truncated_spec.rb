RSpec.describe Loba::Internal::Text::Truncated do
  def max_length = described_class::MAX_LENGTH

  context "when the text is within the limit" do
    it "is the text unchanged, with nothing cut", :aggregate_failures do
      text = "a" * max_length

      truncated = described_class.new(text)

      expect(truncated.to_s).to eq(text)
      expect(truncated.cut?).to be(false)
      expect(truncated.chars_cut).to eq(0)
    end
  end

  context "when the text is longer than the limit" do
    it "keeps the first MAX_LENGTH characters, then marks how many more there were",
       :aggregate_failures do
      truncated = described_class.new("#{'a' * max_length}#{'b' * 23}")

      expect(truncated.to_s).to eq("#{'a' * max_length} [+23 chars]")
      expect(truncated.cut?).to be(true)
      expect(truncated.chars_cut).to eq(23)
    end

    it "counts characters, not bytes" do
      truncated = described_class.new("é" * (max_length + 1))

      expect(truncated.to_s).to eq("#{'é' * max_length} [+1 chars]")
    end
  end
end
