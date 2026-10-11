RSpec.describe Lba::Internal::Tracker do
  describe "#record" do
    it "assigns seq 1 and site_seq 1 to a call site's first record" do
      tracker = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)

      result = tracker.record(type: "val", file: "app/models/order.rb", line: 10)

      expect(result).to eq(seq: 1, mono_time: 100.0, site_seq: 1, diff: nil)
    end

    it "increments both seq and site_seq on a second call to the same site" do
      tracker = described_class.new
      tracker.record(type: "val", file: "app/models/order.rb", line: 10)

      result = tracker.record(type: "val", file: "app/models/order.rb", line: 10)

      expect(result).to include(seq: 2, site_seq: 2)
    end

    it "shares one global seq counter across call sites" do
      tracker = described_class.new
      tracker.record(type: "val", file: "app/models/order.rb", line: 10)

      result = tracker.record(type: "val", file: "app/models/invoice.rb", line: 20)

      expect(result).to include(seq: 2)
    end

    it "reports diff as the elapsed time since the previous record at the same site" do
      tracker = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)
      tracker.record(type: "val", file: "app/models/order.rb", line: 10)

      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.25)
      result = tracker.record(type: "val", file: "app/models/order.rb", line: 10)

      expect(result).to include(diff: 0.25)
    end

    # A record's diff and since_prev_ts must equal the gap between the
    # mono_time values written on its lines, so the reading they're measured
    # from is the one written.
    it "reports the clock reading its timing was measured from" do
      tracker = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.25)

      result = tracker.record(type: "ts", file: "app/models/order.rb", line: 10)

      expect(result).to include(mono_time: 100.25)
    end

    it "requires the record type, with no default" do
      tracker = described_class.new

      expect { tracker.record(file: "app/models/order.rb", line: 10) }
        .to raise_error(ArgumentError, /type/)
    end

    describe "what counts as a separate call site" do
      it "gives another file its own site_seq and diff" do
        tracker = described_class.new
        tracker.record(type: "val", file: "app/models/order.rb", line: 10)

        result = tracker.record(type: "val", file: "app/models/invoice.rb", line: 10)

        expect(result).to include(site_seq: 1, diff: nil)
      end

      it "gives another line in the same file its own site_seq and diff" do
        tracker = described_class.new
        tracker.record(type: "val", file: "app/models/order.rb", line: 10)

        result = tracker.record(type: "val", file: "app/models/order.rb", line: 11)

        expect(result).to include(site_seq: 1, diff: nil)
      end

      it "gives another record type on the same line its own site_seq and diff" do
        tracker = described_class.new
        tracker.record(type: "val", file: "app/models/order.rb", line: 10)

        result = tracker.record(type: "ts", file: "app/models/order.rb", line: 10)

        expect(result).to include(site_seq: 1, diff: nil)
      end

      it "still numbers a val and a ts on the same line in one global seq" do
        tracker = described_class.new
        tracker.record(type: "val", file: "app/models/order.rb", line: 10)

        result = tracker.record(type: "ts", file: "app/models/order.rb", line: 10)

        expect(result).to include(seq: 2)
      end
    end

    describe "since_prev_ts" do
      def stub_monotonic(time)
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(time)
      end

      it "is nil on the process's first ts record" do
        tracker = described_class.new

        result = tracker.record(type: "ts", file: "app/models/order.rb", line: 10)

        expect(result).to include(since_prev_ts: nil)
      end

      it "is the elapsed time since the previous ts record, at any site" do
        tracker = described_class.new
        stub_monotonic(100.0)
        tracker.record(type: "ts", file: "app/models/order.rb", line: 10)

        stub_monotonic(100.5)
        result = tracker.record(type: "ts", file: "app/models/invoice.rb", line: 20)

        expect(result).to include(since_prev_ts: 0.5)
      end

      it "ignores val records between two ts records" do
        tracker = described_class.new
        stub_monotonic(100.0)
        tracker.record(type: "ts", file: "app/models/order.rb", line: 10)
        stub_monotonic(100.2)
        tracker.record(type: "val", file: "app/models/order.rb", line: 11)

        stub_monotonic(100.5)
        result = tracker.record(type: "ts", file: "app/models/order.rb", line: 12)

        expect(result).to include(since_prev_ts: 0.5)
      end

      it "is left off val records" do
        tracker = described_class.new
        tracker.record(type: "ts", file: "app/models/order.rb", line: 10)

        result = tracker.record(type: "val", file: "app/models/order.rb", line: 11)

        expect(result).not_to have_key(:since_prev_ts)
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
        described_class.current.record(type: "val", file: "app/models/order.rb", line: 10)

        child_result = in_forked_child do
          described_class.current.record(type: "val", file: "app/models/order.rb", line: 10)
        end

        expect(child_result).to include(seq: 1, site_seq: 1)
      end

      it "gives the child a fresh since_prev_ts instead of timing from the parent's ts" do
        stub_tracker_at_exit
        described_class.current.record(type: "ts", file: "app/models/order.rb", line: 10)

        child_result = in_forked_child do
          described_class.current.record(type: "ts", file: "app/models/order.rb", line: 10)
        end

        expect(child_result).to include(since_prev_ts: nil)
      end
    end
  end
end
