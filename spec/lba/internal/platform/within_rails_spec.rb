RSpec.describe Lba::Internal::Platform::WithinRails do
  describe ".app?" do
    it "is true when Rails is loaded" do
      stub_const("Rails", mock_rails(production: false))

      expect(described_class.app?).to be true
    end

    it "is false when Rails isn't loaded" do
      hide_const("Rails")

      expect(described_class.app?).to be false
    end

    it "is false when only a Rails namespace is defined" do
      stub_const("Rails", Module.new)

      expect(described_class.app?).to be false
    end
  end

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

    # Gems such as rails-html-sanitizer define a Rails namespace without Rails.
    context "when only a Rails namespace is defined" do
      it "returns false" do
        stub_const("Rails", Module.new)

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

    context "when only a Rails namespace is defined" do
      it "returns false" do
        stub_const("Rails", Module.new)

        expect(described_class.production?).to be false
      end
    end
  end
end
