require "json"
require "logger"
require "stringio"

RSpec.describe Lba::Internal::Destination do
  describe "#write" do
    it "appends the record to the sink as a JSON line" do
      sink = StringIO.new
      destination = described_class.new(sink:, logger: nil)

      destination.write({ seq: 1, type: "ts" })

      expect(sink.string).to eq("{\"seq\":1,\"type\":\"ts\"}\n")
    end

    it "also writes the same JSON to the logger, at debug level", :aggregate_failures do
      log_output = StringIO.new
      logger = Logger.new(log_output, level: :debug)
      destination = described_class.new(sink: StringIO.new, logger:)

      destination.write({ seq: 1, type: "ts" })

      expect(log_output.string).to include("DEBUG")
      expect(log_output.string).to include("{\"seq\":1,\"type\":\"ts\"}")
    end
  end
end
