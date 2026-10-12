require "json"
require "logger"
require "stringio"

RSpec.describe Lba::Internal::Destination do
  describe "#write" do
    it "appends the record to the sink as a JSON line" do
      sink = StringIO.new
      destination = described_class.new(sink:, log_mirror: nil)

      destination.write({ seq: 1, type: "ts" })

      expect(sink.string).to eq("{\"seq\":1,\"type\":\"ts\"}\n")
    end

    it "also writes the same JSON to the logger, at debug level", :aggregate_failures do
      log_output = StringIO.new
      logger = Logger.new(log_output, level: :debug)
      log_mirror = Lba::Internal::LogMirror.new(logger:)
      destination = described_class.new(sink: StringIO.new, log_mirror:)

      destination.write({ seq: 1, type: "ts" })

      expect(log_output.string).to include("DEBUG")
      expect(log_output.string).to include("{\"seq\":1,\"type\":\"ts\"}")
    end
  end
end
