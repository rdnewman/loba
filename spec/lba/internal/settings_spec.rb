RSpec.describe Lba::Internal::Settings do
  describe "#enabled?" do
    context "when in Rails and not in a production environment" do
      it "is true" do
        stub_const("Rails", mock_rails(production: false))

        settings = described_class.new

        expect(settings.enabled?).to be true
      end
    end

    context "when in Rails and in a production environment" do
      it "is false" do
        stub_const("Rails", mock_rails(production: true))

        settings = described_class.new

        expect(settings.enabled?).to be false
      end

      it "cannot be forced on -- there is no override" do
        stub_const("Rails", mock_rails(production: true))

        expect { described_class.new(production: true) }.to raise_error(ArgumentError)
      end
    end

    context "without Rails" do
      it "is true" do
        hide_const("Rails")

        settings = described_class.new

        expect(settings.enabled?).to be true
      end
    end
  end

  describe "#disabled?" do
    it "is the inverse of #enabled?" do
      hide_const("Rails")

      settings = described_class.new

      expect(settings.disabled?).to be false
    end
  end

  describe "when disabled" do
    it "does not validate or expose a logger" do
      stub_const("Rails", mock_rails(production: true))

      settings = described_class.new(logger: "not a logger")

      expect(settings.logger).to be_nil
    end
  end
end
