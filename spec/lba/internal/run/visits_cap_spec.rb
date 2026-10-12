require "json"
require "stringio"

RSpec.describe Lba::Internal::Run::Visits do
  subject(:visits) { described_class.new }

  let(:discarding_destination) { destination_to(instance_double(IO, write: nil, flush: nil)) }
  let(:site) { Lba::Internal::Site.new(type: "val", file: "app/models/order.rb", line: 10) }
  let(:cap) { 500 }

  describe "#record with a write-time cap" do
    it "suppresses the call that crosses the cap without writing anything", :aggregate_failures do
      sink = instance_double(IO, write: nil, flush: nil)
      destination = destination_to(sink)
      cap.times { visits.record(site, destination:) }

      result = visits.record(site, destination:)

      expect(result).to eq(:suppressed)
      expect(sink).not_to have_received(:write)
    end

    it "keeps skipping a capped site's calls until 60 seconds have passed" do
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)
      (cap + 1).times { visits.record(site, destination: discarding_destination) }
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 59.9)

      result = visits.record(site, destination: discarding_destination)

      expect(result).to eq(:suppressed)
    end

    it "caps a ts on the same line separately from a capped val" do
      (cap + 1).times { visits.record(site, destination: discarding_destination) }

      result = visits.record(site.with(type: "ts"), destination: discarding_destination)

      expect(result).to include(site_seq: 1)
    end
  end

  describe "flushing a completed window" do
    # rubocop:disable-next RSpec/ExampleLength -- the window setup and the full
    # record check both need their lines.
    it "writes exactly one suppression record with the true suppressed count " \
       "once the window resets", :aggregate_failures do
      sink = StringIO.new
      destination = destination_to(sink)
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)

      cap.times { visits.record(site, destination:) }
      7.times { visits.record(site, destination:) }

      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 60)
      visits.record(site, destination:)

      lines = sink.string.lines
      expect(lines.size).to eq(1)

      flushed = JSON.parse(lines.first)
      expect(flushed).to include(
        "type" => "val", "file" => "app/models/order.rb", "line" => 10,
        "suppressed" => true, "suppressed_count" => 7
      )
    end

    it "writes to the site's destination even when the call that ends the window passes none" do
      sink = StringIO.new
      destination = destination_to(sink)
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)
      (cap + 1).times { visits.record(site, destination:) }
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 60)

      visits.record(site)

      expect(JSON.parse(sink.string)).to include("suppressed_count" => 1)
    end

    # rubocop:disable-next RSpec/ExampleLength -- the window setup and the full
    # stamp check both need their lines.
    it "stamps the suppression record like any other record, with the next seq",
       :aggregate_failures do
      sink = StringIO.new
      destination = destination_to(sink)
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)
      (cap + 1).times { visits.record(site, destination:) }
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 60)

      next_record = visits.record(site, destination:)

      flushed = JSON.parse(sink.string, symbolize_names: true)
      expect(flushed).to include(
        schema: 1, run_id: Lba::Internal::Run.current.id, seq: cap + 1,
        mono_time: window_start + 60
      )
      expect(flushed[:wall_time]).to be_a(Float)
      expect(next_record).to include(seq: cap + 2)
    end

    it "uses up no numbers on skipped calls" do
      window_start = 1_000.0
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start)
      (cap + 4).times { visits.record(site, destination: discarding_destination) }
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(window_start + 60)

      result = visits.record(site, destination: discarding_destination)

      # The suppression record written as the window rolled over took the seq
      # just before this one.
      expect(result).to include(seq: cap + 2, site_seq: cap + 1)
    end
  end

  describe "since_prev_ts at a capped checkpoint site" do
    def stub_monotonic(time)
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(time)
    end

    def record_checkpoint(site)
      visits.record(site, destination: discarding_destination, checkpoint: true)
    end

    it "is not advanced by skipped calls" do
      checkpoint_site = site.with(type: "ts")
      stub_monotonic(100.0)
      cap.times { record_checkpoint(checkpoint_site) }
      stub_monotonic(100.3)
      record_checkpoint(checkpoint_site)

      stub_monotonic(100.5)
      result = record_checkpoint(checkpoint_site.with(line: 20))

      expect(result).to include(since_prev_ts: 0.5)
    end

    it "times from the previous checkpoint, not the suppression record written just before it" do
      checkpoint_site = site.with(type: "ts")
      stub_monotonic(100.0)
      (cap + 1).times { record_checkpoint(checkpoint_site) }

      stub_monotonic(170.0)
      result = record_checkpoint(checkpoint_site)

      expect(result).to include(since_prev_ts: 70.0)
    end
  end
end
