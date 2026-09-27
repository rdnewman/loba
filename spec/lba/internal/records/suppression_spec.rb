require "json"
require "stringio"

RSpec.describe Lba::Internal::Records::Suppression do
  describe ".write" do
    it "writes one JSON line counting the site's skipped calls", :aggregate_failures do
      sink = StringIO.new

      described_class.write(
        type: "ts", file: "app/models/order.rb", line: 10, suppressed_count: 7, seq: 42, sink:
      )

      lines = sink.string.lines
      expect(lines.size).to eq(1)
      expect(JSON.parse(lines.first, symbolize_names: true)).to include(
        type: "ts", seq: 42, file: "app/models/order.rb", line: 10,
        suppressed: true, suppressed_count: 7
      )
    end

    it "opens with the same stamp as every record, then the site and count" do
      sink = StringIO.new

      described_class.write(
        type: "val", file: "app/models/order.rb", line: 10, suppressed_count: 1, seq: 1, sink:
      )

      keys = JSON.parse(sink.string, symbolize_names: true).keys
      expect(keys).to eq(
        [:schema, :run_id, :seq, :type, :wall_time, :mono_time,
         :file, :line, :suppressed, :suppressed_count]
      )
    end
  end
end
