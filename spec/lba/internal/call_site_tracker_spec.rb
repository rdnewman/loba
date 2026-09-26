RSpec.describe Lba::Internal::CallSiteTracker do
  describe "#record" do
    it "assigns seq 1 and site_seq 1 to a call site's first record" do
      tracker = described_class.new

      result = tracker.record("app/models/order.rb:10")

      expect(result).to eq(seq: 1, site_seq: 1, diff: nil)
    end

    it "increments both seq and site_seq on a second call to the same site" do
      tracker = described_class.new
      tracker.record("app/models/order.rb:10")

      result = tracker.record("app/models/order.rb:10")

      expect(result).to include(seq: 2, site_seq: 2)
    end

    it "tracks site_seq independently per call site" do
      tracker = described_class.new
      tracker.record("app/models/order.rb:10")
      tracker.record("app/models/order.rb:10")

      result = tracker.record("app/models/invoice.rb:20")

      expect(result).to include(site_seq: 1)
    end

    it "shares one global seq counter across call sites" do
      tracker = described_class.new
      tracker.record("app/models/order.rb:10")

      result = tracker.record("app/models/invoice.rb:20")

      expect(result).to include(seq: 2)
    end

    it "reports diff as the elapsed time since the previous record at the same site" do
      tracker = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)
      tracker.record("app/models/order.rb:10")

      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.25)
      result = tracker.record("app/models/order.rb:10")

      expect(result).to include(diff: 0.25)
    end

    it "tracks diff independently per call site" do
      tracker = described_class.new
      tracker.record("app/models/order.rb:10")

      result = tracker.record("app/models/invoice.rb:20")

      expect(result).to include(diff: nil)
    end
  end

  describe ".current" do
    after { reset_current(described_class) }

    it "returns a CallSiteTracker instance" do
      stub_call_site_tracker_at_exit

      expect(described_class.current).to be_a(described_class)
    end

    it "memoizes the same instance across repeated calls" do
      stub_call_site_tracker_at_exit

      expect(described_class.current).to equal(described_class.current)
    end

    context "when the process forks after .current is memoized" do
      it "gives the child fresh counters instead of continuing the parent's" do
        stub_call_site_tracker_at_exit
        described_class.current.record("app/models/order.rb:10")

        child_result = in_forked_child { described_class.current.record("app/models/order.rb:10") }

        expect(child_result).to include(seq: 1, site_seq: 1)
      end
    end
  end
end
