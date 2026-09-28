RSpec.describe Lba::Internal::CallSiteTracker::Window do
  describe "#count_call" do
    it "doesn't skip calls up to the cap" do
      window = described_class.new

      5.times { window.count_call(cap: 5) }

      expect(window).not_to be_skipping
    end

    it "skips the call that crosses the cap" do
      window = described_class.new
      5.times { window.count_call(cap: 5) }

      window.count_call(cap: 5)

      expect(window).to be_skipping
    end

    it "keeps skipping once it has skipped, even under a larger cap" do
      window = described_class.new
      6.times { window.count_call(cap: 5) }

      window.count_call(cap: 100)

      expect(window.skipped).to eq(2)
    end

    it "counts each skipped call", :aggregate_failures do
      window = described_class.new
      expect(window.skipped).to eq(0)

      8.times { window.count_call(cap: 5) }

      expect(window.skipped).to eq(3)
    end
  end

  describe "#roll" do
    it "starts the window at its first roll, open for its length", :aggregate_failures do
      window = described_class.new
      window.roll(now: 100.0, length: 60)
      6.times { window.count_call(cap: 5) }

      window.roll(now: 159.9, length: 60)

      expect(window).to be_skipping
      expect(window.skipped).to eq(1)
    end

    it "ends the window once its length has passed, returning the calls it skipped" do
      window = described_class.new
      window.roll(now: 100.0, length: 60)
      7.times { window.count_call(cap: 5) }

      expect(window.roll(now: 160.0, length: 60)).to eq(2)
    end

    it "returns 0 for an open window, or an ended one that skipped nothing", :aggregate_failures do
      window = described_class.new

      expect(window.roll(now: 100.0, length: 60)).to eq(0)
      expect(window.roll(now: 160.0, length: 60)).to eq(0)
    end

    it "starts a fresh window, with a fresh cap, when one ends", :aggregate_failures do
      window = described_class.new
      window.roll(now: 100.0, length: 60)
      6.times { window.count_call(cap: 5) }

      window.roll(now: 160.0, length: 60)
      5.times { window.count_call(cap: 5) }

      expect(window).not_to be_skipping
      expect(window.skipped).to eq(0)
    end

    it "times the fresh window from the roll that started it" do
      window = described_class.new
      window.roll(now: 100.0, length: 60)
      window.roll(now: 170.0, length: 60)
      6.times { window.count_call(cap: 5) }

      expect(window.roll(now: 229.9, length: 60)).to eq(0)
    end
  end
end
