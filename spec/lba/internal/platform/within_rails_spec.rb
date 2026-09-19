RSpec.describe Lba::Internal::Platform::WithinRails do
  describe ".logger?" do
    context "when not in Rails" do
      it "returns false" do
        hide_const("Rails")

        expect(described_class.logger?).to be false
      end
    end

    context "when in Rails" do
      it "returns true when Rails.logger is present" do
        stub_const("Rails", mock_rails(production: false, logger: Object.new))

        expect(described_class.logger?).to be true
      end

      it "returns false when Rails.logger is nil" do
        stub_const("Rails", mock_rails(production: false, logger: nil))

        expect(described_class.logger?).to be false
      end
    end
  end

  describe ".production?" do
    context "when not in Rails" do
      it "returns false" do
        hide_const("Rails")

        expect(described_class.production?).to be false
      end
    end

    context "when in Rails" do
      it "returns true when Rails.env.production? is true" do
        stub_const("Rails", mock_rails(production: true))

        expect(described_class.production?).to be true
      end

      it "returns false when Rails.env.production? is false" do
        stub_const("Rails", mock_rails(production: false))

        expect(described_class.production?).to be false
      end
    end
  end
end
