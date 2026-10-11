require "json"
require "logger"
require "stringio"

RSpec.describe Lba::Internal::Records::Suppression do
  describe ".write" do
    it "writes one JSON line counting the site's skipped calls", :aggregate_failures do
      sink = StringIO.new
      destination = destination_to(sink)

      described_class.write(
        site: Lba::Internal::Site.new(type: "ts", file: "app/models/order.rb", line: 10),
        suppressed_count: 7, seq: 42, destination:
      )

      lines = sink.string.lines
      expect(lines.size).to eq(1)
      expect(JSON.parse(lines.first, symbolize_names: true)).to include(
        type: "ts", seq: 42, file: "app/models/order.rb", line: 10,
        suppressed: true, suppressed_count: 7
      )
    end

    it "mirrors the record to the destination's logger, like any record" do
      sink = StringIO.new
      log_output = StringIO.new
      destination = destination_to(sink, logger: Logger.new(log_output))

      described_class.write(
        site: Lba::Internal::Site.new(type: "val", file: "app/models/order.rb", line: 10),
        suppressed_count: 3, seq: 9, destination:
      )

      expect(log_output.string).to include(sink.string.chomp)
    end

    it "has the order and site first, then the count, then the same stamp as every record" do
      sink = StringIO.new
      destination = destination_to(sink)

      described_class.write(
        site: Lba::Internal::Site.new(type: "val", file: "app/models/order.rb", line: 10),
        suppressed_count: 1, seq: 1, destination:
      )

      keys = JSON.parse(sink.string, symbolize_names: true).keys
      expect(keys).to eq(
        [:seq, :type, :file, :line, :suppressed, :suppressed_count,
         :wall_time, :mono_time, :run_id, :schema]
      )
    end
  end
end
