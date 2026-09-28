require "json"
require "stringio"

RSpec.describe Lba::Internal::CallSiteTracker::Site do
  it "is one record type at one file and line", :aggregate_failures do
    site = described_class.new(type: "ts", file: "app/models/order.rb", line: 10)

    expect(site.type).to eq("ts")
    expect(site.file).to eq("app/models/order.rb")
    expect(site.line).to eq(10)
  end

  describe "#advance" do
    it "numbers the site's first record 1, with no diff" do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)

      expect(site.advance(100.0)).to eq(site_seq: 1, diff: nil)
    end

    it "numbers each later record in turn, with the time since the previous one" do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)
      site.advance(100.0)

      expect(site.advance(100.25)).to eq(site_seq: 2, diff: 0.25)
    end

    it "keeps numbering and timing across a window that ends with skipped calls" do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)
      site.remember_sink(StringIO.new)
      site.roll(now: 100.0, length: 60) { 1 }
      6.times { site.count_call(cap: 5) }
      site.advance(100.0)
      site.roll(now: 161.0, length: 60) { 2 }

      expect(site.advance(161.0)).to eq(site_seq: 2, diff: 61.0)
    end
  end

  describe "#remember_sink" do
    it "starts with no sink" do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)

      expect(site.sink).to be_nil
    end

    it "keeps the latest sink it's given" do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)
      site.remember_sink(StringIO.new)
      latest = StringIO.new

      site.remember_sink(latest)

      expect(site.sink).to equal(latest)
    end

    it "keeps its sink when given none" do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)
      sink = StringIO.new
      site.remember_sink(sink)

      site.remember_sink(nil)

      expect(site.sink).to equal(sink)
    end
  end

  describe "#count_call" do
    it "counts calls against the cap and reports skipping" do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)

      6.times { site.count_call(cap: 5) }

      expect(site).to be_skipping
    end
  end

  describe "#roll" do
    it "writes a suppression record, numbered on request, when an ended window skipped calls" do
      site = described_class.new(type: "ts", file: "app/models/order.rb", line: 10)
      sink = StringIO.new
      site.remember_sink(sink)
      site.roll(now: 100.0, length: 60) { 1 }
      7.times { site.count_call(cap: 5) }

      site.roll(now: 160.0, length: 60) { 42 }

      expect(JSON.parse(sink.string, symbolize_names: true)).to include(
        seq: 42, type: "ts", file: "app/models/order.rb", line: 10, suppressed_count: 2
      )
    end

    it "writes nothing, and asks for no number, while its window is open", :aggregate_failures do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)
      sink = StringIO.new
      site.remember_sink(sink)
      site.roll(now: 100.0, length: 60) { 1 }
      6.times { site.count_call(cap: 5) }
      asked = false

      site.roll(now: 159.9, length: 60) { asked = true }

      expect(sink.string).to be_empty
      expect(asked).to be(false)
    end

    it "writes nothing, and asks for no number, when an ended window skipped none",
       :aggregate_failures do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)
      sink = StringIO.new
      site.remember_sink(sink)
      site.roll(now: 100.0, length: 60) { 1 }
      asked = false

      site.roll(now: 160.0, length: 60) { asked = true }

      expect(sink.string).to be_empty
      expect(asked).to be(false)
    end
  end

  describe "#flush" do
    it "writes a suppression record for the open window's skipped calls" do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)
      sink = StringIO.new
      site.remember_sink(sink)
      6.times { site.count_call(cap: 5) }

      site.flush { 7 }

      expect(JSON.parse(sink.string, symbolize_names: true))
        .to include(seq: 7, suppressed: true, suppressed_count: 1)
    end

    it "writes nothing, and asks for no number, when its window skipped none",
       :aggregate_failures do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)
      sink = StringIO.new
      site.remember_sink(sink)
      asked = false

      site.flush { asked = true }

      expect(sink.string).to be_empty
      expect(asked).to be(false)
    end
  end
end
