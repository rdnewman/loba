require "json"
require "stringio"

RSpec.describe Lba::Internal::CallSiteTracker do
  subject(:tracker) { described_class.new }

  let(:sink) { instance_double(IO, write: nil, flush: nil) }
  let(:site_key) { "app/models/order.rb:10" }

  describe "#record with a write-time cap" do
    it "returns normal records for every call up to the cap" do
      results = Array.new(5) { |i| tracker.record(site_key, value: i, sink:, cap: 5) }

      expect(results).to all(include(:seq, :site_seq, :changed, :prev_value))
    end

    it "suppresses the call that crosses the cap without writing anything", :aggregate_failures do
      5.times { |i| tracker.record(site_key, value: i, sink:, cap: 5) }

      result = tracker.record(site_key, value: :over, sink:, cap: 5)

      expect(result).to eq(:suppressed)
      expect(sink).not_to have_received(:write)
    end

    it "stays suppressed and writes nothing through a large burst past the cap",
       :aggregate_failures do
      5.times { |i| tracker.record(site_key, value: i, sink:, cap: 5) }

      results = Array.new(10_000) { |i| tracker.record(site_key, value: i, sink:, cap: 5) }

      expect(results).to all(eq(:suppressed))
      expect(sink).not_to have_received(:write)
    end

    it "defaults the cap to 500 records per window" do
      500.times { |i| tracker.record(site_key, value: i, sink:) }

      result = tracker.record(site_key, value: :over, sink:)

      expect(result).to eq(:suppressed)
    end
  end

  describe "#suppressed?" do
    it "is false before the cap is reached" do
      4.times { |i| tracker.record(site_key, value: i, sink:, cap: 5) }

      expect(tracker.suppressed?(site_key, sink:)).to be false
    end

    it "is true once the cap has been crossed" do
      6.times { |i| tracker.record(site_key, value: i, sink:, cap: 5) }

      expect(tracker.suppressed?(site_key, sink:)).to be true
    end

    it "does not write anything merely by being checked" do
      6.times { |i| tracker.record(site_key, value: i, sink:, cap: 5) }

      tracker.suppressed?(site_key, sink:)

      expect(sink).not_to have_received(:write)
    end
  end

  describe "flushing a completed window" do
    it "writes exactly one suppression record with the true suppressed count " \
       "once the window resets", :aggregate_failures do
      sink = StringIO.new
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)

      5.times { |i| tracker.record(site_key, value: i, sink:, cap: 5, window: 60) }
      7.times { |i| tracker.record(site_key, value: i, sink:, cap: 5, window: 60) }

      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 61)
      tracker.record(site_key, value: :next_window, sink:, cap: 5, window: 60)

      lines = sink.string.lines
      expect(lines.size).to eq(1)

      flushed = JSON.parse(lines.first)
      expect(flushed).to include(
        "type" => "val", "site" => site_key, "suppressed" => true, "suppressed_count" => 7
      )
    end

    it "resets the site's cap so the new window starts fresh", :aggregate_failures do
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)

      6.times { |i| tracker.record(site_key, value: i, sink:, cap: 5, window: 60) }

      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 61)
      result = tracker.record(site_key, value: :next_window, sink:, cap: 5, window: 60)

      expect(result).not_to eq(:suppressed)
      expect(result).to include(site_seq: 1)
    end

    it "keeps value-diffing state across a window reset (unaffected by cap bookkeeping)" do
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)

      5.times { |i| tracker.record(site_key, value: i, sink:, cap: 5, window: 60) }
      6.times { tracker.record(site_key, value: :over, sink:, cap: 5, window: 60) }

      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 61)
      result = tracker.record(site_key, value: 4, sink:, cap: 5, window: 60)

      expect(result).to include(changed: false, prev_value: 4)
    end
  end
end
