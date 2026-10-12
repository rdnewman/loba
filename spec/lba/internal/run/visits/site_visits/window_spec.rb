RSpec.describe Lba::Internal::Run::Visits::SiteVisits::Window do
  let(:cap) { 500 }

  describe "#count_call" do
    it "doesn't skip calls up to the cap" do
      window = described_class.new

      cap.times { window.count_call }

      expect(window).not_to be_skipping
    end

    it "skips the call that crosses the cap" do
      window = described_class.new
      cap.times { window.count_call }

      window.count_call

      expect(window).to be_skipping
    end

    it "counts each skipped call", :aggregate_failures do
      window = described_class.new
      expect(window.skipped).to eq(0)

      (cap + 3).times { window.count_call }

      expect(window.skipped).to eq(3)
    end
  end

  describe "#roll" do
    it "starts the window at its first roll, open for its length", :aggregate_failures do
      window = described_class.new
      window.roll(now: 100.0)
      (cap + 1).times { window.count_call }

      window.roll(now: 159.9)

      expect(window).to be_skipping
      expect(window.skipped).to eq(1)
    end

    it "ends the window once its length has passed, returning the calls it skipped" do
      window = described_class.new
      window.roll(now: 100.0)
      (cap + 2).times { window.count_call }

      expect(window.roll(now: 160.0)).to eq(2)
    end

    it "returns 0 for an open window, or an ended one that skipped nothing", :aggregate_failures do
      window = described_class.new

      expect(window.roll(now: 100.0)).to eq(0)
      expect(window.roll(now: 160.0)).to eq(0)
    end

    it "starts a fresh window, with a fresh cap, when one ends", :aggregate_failures do
      window = described_class.new
      window.roll(now: 100.0)
      (cap + 1).times { window.count_call }

      window.roll(now: 160.0)
      cap.times { window.count_call }

      expect(window).not_to be_skipping
      expect(window.skipped).to eq(0)
    end

    it "times the fresh window from the roll that started it" do
      window = described_class.new
      window.roll(now: 100.0)
      window.roll(now: 170.0)
      (cap + 1).times { window.count_call }

      expect(window.roll(now: 229.9)).to eq(0)
    end
  end
end
