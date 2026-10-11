RSpec.describe Lba::Internal::Tracker do
  def site(type: "val", file: "app/models/order.rb", line: 10)
    Lba::Internal::Site.new(type:, file:, line:)
  end

  describe "#record" do
    it "assigns seq 1 and site_seq 1 to a call site's first record" do
      tracker = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)

      result = tracker.record(site)

      expect(result).to eq(seq: 1, mono_time: 100.0, site_seq: 1, diff: nil)
    end

    it "increments both seq and site_seq on a second call to the same site" do
      tracker = described_class.new
      tracker.record(site)

      result = tracker.record(site)

      expect(result).to include(seq: 2, site_seq: 2)
    end

    it "shares one global seq counter across call sites" do
      tracker = described_class.new
      tracker.record(site)

      result = tracker.record(site(file: "app/models/invoice.rb", line: 20))

      expect(result).to include(seq: 2)
    end

    it "reports diff as the elapsed time since the previous record at the same site" do
      tracker = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)
      tracker.record(site)

      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.25)
      result = tracker.record(site)

      expect(result).to include(diff: 0.25)
    end

    # A record's diff and since_prev_ts must equal the gap between the
    # mono_time values written on its lines, so the reading they're measured
    # from is the one written.
    it "reports the clock reading its timing was measured from" do
      tracker = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.25)

      result = tracker.record(site(type: "ts"))

      expect(result).to include(mono_time: 100.25)
    end

    describe "what counts as a separate call site" do
      it "gives another file its own site_seq and diff" do
        tracker = described_class.new
        tracker.record(site)

        result = tracker.record(site(file: "app/models/invoice.rb"))

        expect(result).to include(site_seq: 1, diff: nil)
      end

      it "gives another line in the same file its own site_seq and diff" do
        tracker = described_class.new
        tracker.record(site)

        result = tracker.record(site(line: 11))

        expect(result).to include(site_seq: 1, diff: nil)
      end

      it "gives another record type on the same line its own site_seq and diff" do
        tracker = described_class.new
        tracker.record(site)

        result = tracker.record(site(type: "ts"))

        expect(result).to include(site_seq: 1, diff: nil)
      end

      it "still numbers a val and a ts on the same line in one global seq" do
        tracker = described_class.new
        tracker.record(site)

        result = tracker.record(site(type: "ts"))

        expect(result).to include(seq: 2)
      end
    end

    describe "since_prev_ts" do
      def stub_monotonic(time)
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(time)
      end

      it "is nil on the process's first checkpoint" do
        tracker = described_class.new

        result = tracker.record(site(type: "ts"), checkpoint: true)

        expect(result).to include(since_prev_ts: nil)
      end

      it "is the time since the previous checkpoint, at any site" do
        tracker = described_class.new
        stub_monotonic(100.0)
        tracker.record(site(type: "ts"), checkpoint: true)

        stub_monotonic(100.5)
        result = tracker.record(site(type: "ts", file: "app/models/invoice.rb"), checkpoint: true)

        expect(result).to include(since_prev_ts: 0.5)
      end

      it "ignores calls that aren't checkpoints between two checkpoints" do
        tracker = described_class.new
        stub_monotonic(100.0)
        tracker.record(site(type: "ts"), checkpoint: true)
        stub_monotonic(100.2)
        tracker.record(site(line: 11))

        stub_monotonic(100.5)
        result = tracker.record(site(type: "ts", line: 12), checkpoint: true)

        expect(result).to include(since_prev_ts: 0.5)
      end

      it "is left off calls that aren't checkpoints" do
        tracker = described_class.new
        tracker.record(site(type: "ts"), checkpoint: true)

        result = tracker.record(site(line: 11))

        expect(result).not_to have_key(:since_prev_ts)
      end

      it "doesn't count a call as a checkpoint for its site's type" do
        tracker = described_class.new
        stub_monotonic(100.0)
        tracker.record(site(type: "ts"), checkpoint: true)
        stub_monotonic(100.2)
        tracker.record(site(type: "ts", line: 11))

        stub_monotonic(100.5)
        result = tracker.record(site(type: "ts", line: 12), checkpoint: true)

        expect(result).to include(since_prev_ts: 0.5)
      end

      it "counts a call the caller says is a checkpoint, whatever its site's type" do
        tracker = described_class.new
        stub_monotonic(100.0)
        tracker.record(site(type: "ts"), checkpoint: true)

        stub_monotonic(100.5)
        result = tracker.record(site(type: "val"), checkpoint: true)

        expect(result).to include(since_prev_ts: 0.5)
      end
    end
  end

  describe ".current" do
    after { reset_current(described_class) }

    it "returns a Tracker instance" do
      stub_tracker_at_exit

      expect(described_class.current).to be_a(described_class)
    end

    it "memoizes the same instance across repeated calls" do
      stub_tracker_at_exit

      expect(described_class.current).to equal(described_class.current)
    end

    context "when the process forks after .current is memoized" do
      it "gives the child fresh counters instead of continuing the parent's" do
        stub_tracker_at_exit
        described_class.current.record(site)

        child_result = in_forked_child do
          described_class.current.record(site)
        end

        expect(child_result).to include(seq: 1, site_seq: 1)
      end

      it "gives the child a fresh since_prev_ts instead of timing from the parent's checkpoint" do
        stub_tracker_at_exit
        described_class.current.record(site(type: "ts"), checkpoint: true)

        child_result = in_forked_child do
          described_class.current.record(site(type: "ts"), checkpoint: true)
        end

        expect(child_result).to include(since_prev_ts: nil)
      end
    end
  end
end
