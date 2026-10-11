require "logger"
require "stringio"

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

    context "without Rails, in a production environment" do
      around do |example|
        saved = ENV.delete("RACK_ENV")
        ENV["RACK_ENV"] = "production"
        example.run
      ensure
        ENV["RACK_ENV"] = saved
      end

      it "is false" do
        hide_const("Rails")

        settings = described_class.new

        expect(settings.enabled?).to be false
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

  describe "#destination" do
    it "has the IO given as its sink" do
      hide_const("Rails")
      sink = StringIO.new

      settings = described_class.new(sink:)

      expect(settings.destination.sink).to equal(sink)
    end

    it "has a sink resolved from the sink given, or from none" do
      hide_const("Rails")
      allow(Lba::Internal::SinkResolver).to receive(:resolve).and_return("resolved.jsonl")

      settings = described_class.new

      expect(settings.destination.sink).to eq("resolved.jsonl")
    end

    it "resolves its sink once, however often it's asked for" do
      hide_const("Rails")
      allow(Lba::Internal::SinkResolver).to receive(:resolve).and_return("resolved.jsonl")
      settings = described_class.new

      2.times { settings.destination }

      expect(Lba::Internal::SinkResolver).to have_received(:resolve).once
    end

    it "carries the Logger given" do
      hide_const("Rails")
      logger = Logger.new(StringIO.new)

      settings = described_class.new(logger:, sink: StringIO.new)

      expect(settings.destination.logger).to equal(logger)
    end
  end

  describe "when disabled" do
    it "does not validate a logger, or give a destination" do
      stub_const("Rails", mock_rails(production: true))

      settings = described_class.new(logger: "not a logger")

      expect(settings.destination).to be_nil
    end

    it "does not resolve a sink, so it never touches the filesystem",
       :aggregate_failures do
      stub_const("Rails", mock_rails(production: true))
      allow(Lba::Internal::SinkResolver).to receive(:resolve)

      settings = described_class.new(sink: "anywhere.jsonl")

      expect(settings.destination).to be_nil
      expect(Lba::Internal::SinkResolver).not_to have_received(:resolve)
    end
  end
end
