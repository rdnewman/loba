require "logger"
require "stringio"

RSpec.describe Lba::Internal::LogMirror do
  describe ".for" do
    context "when :log is explicitly false" do
      it "returns nil with nothing else given" do
        log_mirror = described_class.for(log: false, logger: nil)

        expect(log_mirror).to be_nil
      end

      it "returns nil even with a real logger given" do
        log_mirror = described_class.for(log: false, logger: Logger.new(File::NULL))

        expect(log_mirror).to be_nil
      end

      it "returns nil even with an invalid logger given, without raising", :aggregate_failures do
        log_mirror = nil

        expect { log_mirror = described_class.for(log: false, logger: "not a logger") }
          .not_to raise_error
        expect(log_mirror).to be_nil
      end

      it "treats any recognized falsy value the same as false" do
        log_mirror = described_class.for(log: 0, logger: nil)

        expect(log_mirror).to be_nil
      end
    end

    context "when :log is explicitly truthy" do
      it "builds a mirror with nothing else given" do
        log_mirror = described_class.for(log: true, logger: nil)

        expect(log_mirror).to be_a(described_class)
      end

      it "treats a non-boolean truthy value the same as true" do
        log_mirror = described_class.for(log: "weird string", logger: nil)

        expect(log_mirror).to be_a(described_class)
      end

      it "mirrors to an explicitly given real logger" do
        log_output = StringIO.new
        log_mirror = described_class.for(log: true, logger: Logger.new(log_output))

        log_mirror.write({ seq: 1 })

        expect(log_output.string).to include("{\"seq\":1}")
      end

      it "raises when given an invalid logger" do
        expect { described_class.for(log: true, logger: "not a logger") }
          .to raise_error(Lba::InvalidLoggerOptionError)
      end

      it "mirrors to Rails.logger when in Rails, even with no logger given" do
        rails_logger = fake_rails_logger
        allow(rails_logger).to receive(:debug)
        stub_const("Rails", mock_rails(logger: rails_logger))
        log_mirror = described_class.for(log: true, logger: nil)

        log_mirror.write({ seq: 1 })

        expect(rails_logger).to have_received(:debug).with("{\"seq\":1}")
      end

      it "mirrors nowhere, without raising, when outside Rails with no logger given" do
        hide_const("Rails")
        log_mirror = described_class.for(log: true, logger: nil)

        expect { log_mirror.write({ seq: 1 }) }.not_to raise_error
      end
    end

    context "when :log is unspecified" do
      it "returns nil when no logger is given" do
        log_mirror = described_class.for(log: nil, logger: nil)

        expect(log_mirror).to be_nil
      end

      it "builds a mirror to an explicitly given real logger" do
        log_output = StringIO.new
        log_mirror = described_class.for(log: nil, logger: Logger.new(log_output))

        log_mirror.write({ seq: 1 })

        expect(log_output.string).to include("{\"seq\":1}")
      end

      it "raises when given a non-nil invalid logger" do
        expect { described_class.for(log: nil, logger: "not a logger") }
          .to raise_error(Lba::InvalidLoggerOptionError)
      end
    end

    context "when the logger gem isn't loaded" do
      it "raises for a candidate logger under an explicit log: true" do
        hide_const("Logger")

        expect { described_class.for(log: true, logger: fake_rails_logger) }
          .to raise_error(Lba::InvalidLoggerOptionError)
      end

      it "raises for a candidate logger when :log is unspecified" do
        hide_const("Logger")

        expect { described_class.for(log: nil, logger: fake_rails_logger) }
          .to raise_error(Lba::InvalidLoggerOptionError)
      end
    end
  end

  describe "#write" do
    it "writes the record to the logger as one JSON line, at debug level", :aggregate_failures do
      log_output = StringIO.new
      log_mirror = described_class.new(logger: Logger.new(log_output, level: :debug))

      log_mirror.write({ seq: 1, type: "ts" })

      expect(log_output.string).to include("DEBUG")
      expect(log_output.string).to include("{\"seq\":1,\"type\":\"ts\"}")
    end

    it "writes nothing at a logger level above debug" do
      log_output = StringIO.new
      log_mirror = described_class.new(logger: Logger.new(log_output, level: :info))

      log_mirror.write({ seq: 1 })

      expect(log_output.string).to be_empty
    end
  end
end
