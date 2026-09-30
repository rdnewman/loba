require "json"
require "stringio"

RSpec.describe Lba::Internal::CallSiteTracker::Site do
  subject(:site) { described_class.new(type: "val", file: "app/models/order.rb", line: 10) }

  describe "#record_call" do
    it "numbers the site's first call 1, with no diff" do
      result = site.record_call(now: 100.0, cap: 5, window_length: 60, sink: StringIO.new) { 1 }

      expect(result).to eq(site_seq: 1, diff: nil)
    end

    it "numbers each later call in turn, with the time since the previous one" do
      site.record_call(now: 100.0, cap: 5, window_length: 60, sink: StringIO.new) { 1 }

      result = site.record_call(now: 100.25, cap: 5, window_length: 60, sink: StringIO.new) { 1 }

      expect(result).to eq(site_seq: 2, diff: 0.25)
    end

    it "suppresses a call past the cap, asking for no number", :aggregate_failures do
      sink = StringIO.new
      2.times { site.record_call(now: 100.0, cap: 2, window_length: 60, sink:) { 1 } }
      asked = false

      result = site.record_call(now: 100.0, cap: 2, window_length: 60, sink:) { asked = true }

      expect(result).to eq(:suppressed)
      expect(asked).to be(false)
      expect(sink.string).to be_empty
    end

    context "when the call ends a window that skipped calls" do
      it "first writes a record counting them, numbered on request, to the site's sink",
         :aggregate_failures do
        site = described_class.new(type: "ts", file: "app/models/order.rb", line: 10)
        sink = StringIO.new
        4.times { site.record_call(now: 100.0, cap: 2, window_length: 60, sink:) { 1 } }

        result = site.record_call(now: 160.0, cap: 2, window_length: 60, sink:) { 42 }

        expect(JSON.parse(sink.string, symbolize_names: true)).to include(
          seq: 42, type: "ts", file: "app/models/order.rb", line: 10,
          suppressed: true, suppressed_count: 2
        )
        expect(result).to include(site_seq: 3)
      end

      it "keeps numbering and timing from the site's last counted call" do
        sink = StringIO.new
        site.record_call(now: 100.0, cap: 2, window_length: 60, sink:) { 1 }
        site.record_call(now: 101.0, cap: 2, window_length: 60, sink:) { 1 }
        site.record_call(now: 102.0, cap: 2, window_length: 60, sink:) { 1 }

        result = site.record_call(now: 161.0, cap: 2, window_length: 60, sink:) { 1 }

        expect(result).to eq(site_seq: 3, diff: 60.0)
      end

      it "writes the record to the latest sink given, even if this call gives none" do
        first_sink = StringIO.new
        latest_sink = StringIO.new
        site.record_call(now: 100.0, cap: 1, window_length: 60, sink: first_sink) { 1 }
        site.record_call(now: 100.0, cap: 1, window_length: 60, sink: latest_sink) { 1 }

        site.record_call(now: 160.0, cap: 1, window_length: 60, sink: nil) { 1 }

        expect(JSON.parse(latest_sink.string)).to include("suppressed_count" => 1)
      end
    end

    context "when the call ends a window that skipped none" do
      it "writes nothing and asks for no number", :aggregate_failures do
        sink = StringIO.new
        site.record_call(now: 100.0, cap: 5, window_length: 60, sink:) { 1 }
        asked = false

        site.record_call(now: 160.0, cap: 5, window_length: 60, sink:) { asked = true }

        expect(sink.string).to be_empty
        expect(asked).to be(false)
      end
    end
  end

  describe "#flush" do
    it "writes a record counting the open window's skipped calls, numbered on request" do
      sink = StringIO.new
      3.times { site.record_call(now: 100.0, cap: 2, window_length: 60, sink:) { 1 } }

      site.flush { 7 }

      expect(JSON.parse(sink.string, symbolize_names: true))
        .to include(seq: 7, type: "val", suppressed: true, suppressed_count: 1)
    end

    it "writes nothing, and asks for no number, when the open window skipped none",
       :aggregate_failures do
      sink = StringIO.new
      site.record_call(now: 100.0, cap: 2, window_length: 60, sink:) { 1 }
      asked = false

      site.flush { asked = true }

      expect(sink.string).to be_empty
      expect(asked).to be(false)
    end
  end

  it "exposes only #record_call and #flush" do
    expect(described_class.public_instance_methods(false)).to contain_exactly(:record_call, :flush)
  end
end
