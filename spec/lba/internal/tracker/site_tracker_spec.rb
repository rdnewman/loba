require "json"
require "stringio"

RSpec.describe Lba::Internal::Tracker::SiteTracker do
  subject(:site_tracker) do
    described_class.new(Lba::Internal::Site.new(type: "val", file: "app/models/order.rb", line: 10))
  end

  let(:cap) { 500 }

  describe "#record_call" do
    it "numbers the site's first call 1, with no diff" do
      result = site_tracker.record_call(now: 100.0, sink: StringIO.new) { 1 }

      expect(result).to eq(site_seq: 1, diff: nil)
    end

    it "numbers each later call in turn, with the time since the previous one" do
      site_tracker.record_call(now: 100.0, sink: StringIO.new) { 1 }

      result = site_tracker.record_call(now: 100.25, sink: StringIO.new) { 1 }

      expect(result).to eq(site_seq: 2, diff: 0.25)
    end

    it "suppresses a call past the cap, asking for no number", :aggregate_failures do
      sink = StringIO.new
      cap.times { site_tracker.record_call(now: 100.0, sink:) { 1 } }
      asked = false

      result = site_tracker.record_call(now: 100.0, sink:) { asked = true }

      expect(result).to eq(:suppressed)
      expect(asked).to be(false)
      expect(sink.string).to be_empty
    end

    context "when the call ends a window that skipped calls" do
      it "first writes a record counting them, numbered on request, to the site's sink",
         :aggregate_failures do
        site_tracker = described_class.new(
          Lba::Internal::Site.new(type: "ts", file: "app/models/order.rb", line: 10)
        )
        sink = StringIO.new
        (cap + 2).times { site_tracker.record_call(now: 100.0, sink:) { 1 } }

        result = site_tracker.record_call(now: 160.0, sink:) { 42 }

        expect(JSON.parse(sink.string, symbolize_names: true)).to include(
          seq: 42, type: "ts", file: "app/models/order.rb", line: 10,
          suppressed: true, suppressed_count: 2
        )
        expect(result).to include(site_seq: cap + 1)
      end

      it "keeps numbering and timing from the site's last counted call" do
        sink = StringIO.new
        (cap - 1).times { site_tracker.record_call(now: 100.0, sink:) { 1 } }
        site_tracker.record_call(now: 101.0, sink:) { 1 }
        site_tracker.record_call(now: 102.0, sink:) { 1 }

        result = site_tracker.record_call(now: 161.0, sink:) { 1 }

        expect(result).to eq(site_seq: cap + 1, diff: 60.0)
      end

      it "writes the record to the latest sink given, even if this call gives none" do
        first_sink = StringIO.new
        latest_sink = StringIO.new
        cap.times { site_tracker.record_call(now: 100.0, sink: first_sink) { 1 } }
        site_tracker.record_call(now: 100.0, sink: latest_sink) { 1 }

        site_tracker.record_call(now: 160.0, sink: nil) { 1 }

        expect(JSON.parse(latest_sink.string)).to include("suppressed_count" => 1)
      end
    end

    context "when the call ends a window that skipped none" do
      it "writes nothing and asks for no number", :aggregate_failures do
        sink = StringIO.new
        site_tracker.record_call(now: 100.0, sink:) { 1 }
        asked = false

        site_tracker.record_call(now: 160.0, sink:) { asked = true }

        expect(sink.string).to be_empty
        expect(asked).to be(false)
      end
    end
  end

  describe "#flush" do
    it "writes a record counting the open window's skipped calls, numbered on request" do
      sink = StringIO.new
      (cap + 1).times { site_tracker.record_call(now: 100.0, sink:) { 1 } }

      site_tracker.flush { 7 }

      expect(JSON.parse(sink.string, symbolize_names: true))
        .to include(seq: 7, type: "val", suppressed: true, suppressed_count: 1)
    end

    it "writes nothing, and asks for no number, when the open window skipped none",
       :aggregate_failures do
      sink = StringIO.new
      site_tracker.record_call(now: 100.0, sink:) { 1 }
      asked = false

      site_tracker.flush { asked = true }

      expect(sink.string).to be_empty
      expect(asked).to be(false)
    end
  end

  it "exposes only #record_call and #flush" do
    expect(described_class.public_instance_methods(false)).to contain_exactly(:record_call, :flush)
  end
end
