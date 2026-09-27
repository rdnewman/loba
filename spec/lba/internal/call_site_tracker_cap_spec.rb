require "json"
require "stringio"

RSpec.describe Lba::Internal::CallSiteTracker do
  subject(:tracker) { described_class.new }

  let(:sink) { instance_double(IO, write: nil, flush: nil) }
  let(:site) { { type: "val", file: "app/models/order.rb", line: 10 } }

  describe "#record with a write-time cap" do
    it "returns normal records for every call up to the cap" do
      results = Array.new(5) { tracker.record(**site, sink:, cap: 5) }

      expect(results).to all(include(:seq, :site_seq))
    end

    it "suppresses the call that crosses the cap without writing anything", :aggregate_failures do
      5.times { tracker.record(**site, sink:, cap: 5) }

      result = tracker.record(**site, sink:, cap: 5)

      expect(result).to eq(:suppressed)
      expect(sink).not_to have_received(:write)
    end

    it "stays suppressed and writes nothing through a large burst past the cap",
       :aggregate_failures do
      5.times { tracker.record(**site, sink:, cap: 5) }

      results = Array.new(10_000) { tracker.record(**site, sink:, cap: 5) }

      expect(results).to all(eq(:suppressed))
      expect(sink).not_to have_received(:write)
    end

    it "defaults the cap to 500 records per window" do
      500.times { tracker.record(**site, sink:) }

      result = tracker.record(**site, sink:)

      expect(result).to eq(:suppressed)
    end

    it "caps a ts on the same line separately from a capped val" do
      6.times { tracker.record(**site, sink:, cap: 5) }

      result = tracker.record(**site, type: "ts", sink:, cap: 5)

      expect(result).to include(site_seq: 1)
    end
  end

  describe "flushing a completed window" do
    # rubocop:disable-next RSpec/ExampleLength -- the window setup and the full
    # record check both need their lines.
    it "writes exactly one suppression record with the true suppressed count " \
       "once the window resets", :aggregate_failures do
      sink = StringIO.new
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)

      5.times { tracker.record(**site, sink:, cap: 5, window: 60) }
      7.times { tracker.record(**site, sink:, cap: 5, window: 60) }

      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 61)
      tracker.record(**site, sink:, cap: 5, window: 60)

      lines = sink.string.lines
      expect(lines.size).to eq(1)

      flushed = JSON.parse(lines.first)
      expect(flushed).to include(
        "type" => "val", "file" => "app/models/order.rb", "line" => 10,
        "suppressed" => true, "suppressed_count" => 7
      )
    end

    it "labels a capped ts site's suppression record with type ts" do
      sink = StringIO.new
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)
      6.times { tracker.record(**site, type: "ts", sink:, cap: 5, window: 60) }
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 61)

      tracker.record(**site, type: "ts", sink:, cap: 5, window: 60)

      expect(JSON.parse(sink.string)).to include("type" => "ts")
    end

    it "stamps the suppression record like any other record, with the next seq",
       :aggregate_failures do
      sink = StringIO.new
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)
      6.times { tracker.record(**site, sink:, cap: 5, window: 60) }
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 61)

      next_record = tracker.record(**site, sink:, cap: 5, window: 60)

      flushed = JSON.parse(sink.string, symbolize_names: true)
      expect(flushed).to include(
        schema: 1, run_id: Lba::Internal::Run.current.id, seq: 6, mono_time: 1_061.0
      )
      expect(flushed[:wall_time]).to be_a(Float)
      expect(next_record).to include(seq: 7)
    end

    it "resets the site's cap so the new window starts fresh", :aggregate_failures do
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)
      6.times { tracker.record(**site, sink:, cap: 5, window: 60) }
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 61)

      next_window = Array.new(6) { tracker.record(**site, sink:, cap: 5, window: 60) }

      expect(next_window.first(5)).to all(be_a(Hash))
      expect(next_window.last).to eq(:suppressed)
    end

    it "continues the site's numbering into the new window" do
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)
      6.times { tracker.record(**site, sink:, cap: 5, window: 60) }
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 61)

      result = tracker.record(**site, sink:, cap: 5, window: 60)

      expect(result).to include(site_seq: 6)
    end

    it "uses up no numbers on skipped calls" do
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)
      9.times { tracker.record(**site, sink:, cap: 5, window: 60) }
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 61)

      result = tracker.record(**site, sink:, cap: 5, window: 60)

      # seq 6 went to the suppression record written as the window rolled over.
      expect(result).to include(seq: 7, site_seq: 6)
    end

    it "keeps diff timing across a window reset (unaffected by cap bookkeeping)",
       :aggregate_failures do
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)

      first = tracker.record(**site, sink:, cap: 5, window: 60)
      6.times { tracker.record(**site, sink:, cap: 5, window: 60) }

      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 61)
      result = tracker.record(**site, sink:, cap: 5, window: 60)

      expect(first).to include(diff: nil)
      expect(result).to include(diff: 61.0)
    end
  end

  describe "since_prev_ts at a capped ts site" do
    def stub_monotonic(time)
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(time)
    end

    it "is not advanced by skipped calls" do
      stub_monotonic(100.0)
      tracker.record(**site, type: "ts", sink:, cap: 1)
      stub_monotonic(100.3)
      tracker.record(**site, type: "ts", sink:, cap: 1)

      stub_monotonic(100.5)
      result = tracker.record(**site, type: "ts", line: 20, sink:, cap: 1)

      expect(result).to include(since_prev_ts: 0.5)
    end

    it "times from the previous checkpoint, not the suppression record written just before it" do
      stub_monotonic(100.0)
      2.times { tracker.record(**site, type: "ts", sink: StringIO.new, cap: 1, window: 60) }

      stub_monotonic(170.0)
      result = tracker.record(**site, type: "ts", sink: StringIO.new, cap: 1, window: 60)

      expect(result).to include(since_prev_ts: 70.0)
    end
  end
end
