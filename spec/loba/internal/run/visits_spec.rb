RSpec.describe Loba::Internal::Run::Visits do
  def site(type: "val", file: "app/models/order.rb", line: 10)
    Loba::Internal::Site.new(type:, file:, line:)
  end

  describe "#note" do
    # A record's since_prev_at_site and since_prev_ts must equal the gap between the
    # mono_time values written on its lines, so the reading they're measured
    # from is the one written.
    it "assigns seq 1 and site_seq 1 to a call site's first record" do
      visits = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)

      result = visits.note(site)

      expect(result).to eq(seq: 1, mono_time: 100.0, site_seq: 1, since_prev_at_site: nil)
    end

    it "increments both seq and site_seq on a second call to the same site" do
      visits = described_class.new
      visits.note(site)

      result = visits.note(site)

      expect(result).to include(seq: 2, site_seq: 2)
    end

    it "shares one global seq counter across call sites" do
      visits = described_class.new
      visits.note(site)

      result = visits.note(site(file: "app/models/invoice.rb", line: 20))

      expect(result).to include(seq: 2)
    end

    it "reports since_prev_at_site as the time since the previous record at the same site" do
      visits = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)
      visits.note(site)

      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.25)
      result = visits.note(site)

      expect(result).to include(since_prev_at_site: 0.25)
    end

    context "when threads note one site at once" do
      it "numbers the site's records apart" do
        visits = described_class.new
        # Holds each thread inside starting the site's visits, where another
        # could start them too.
        allow(described_class::SiteVisits)
          .to receive(:new).and_wrap_original do |original, *arguments|
            sleep 0.05
            original.call(*arguments)
          end

        results = Array.new(2) { Thread.new { visits.note(site) } }.map(&:value)

        expect(results.map { _1[:site_seq] }).to contain_exactly(1, 2)
      end
    end

    describe "what counts as a separate call site" do
      it "gives another file its own site_seq and since_prev_at_site" do
        visits = described_class.new
        visits.note(site)

        result = visits.note(site(file: "app/models/invoice.rb"))

        expect(result).to include(site_seq: 1, since_prev_at_site: nil)
      end

      it "gives another line in the same file its own site_seq and since_prev_at_site" do
        visits = described_class.new
        visits.note(site)

        result = visits.note(site(line: 11))

        expect(result).to include(site_seq: 1, since_prev_at_site: nil)
      end

      it "gives another record type on the same line its own site_seq and since_prev_at_site" do
        visits = described_class.new
        visits.note(site)

        result = visits.note(site(type: "ts"))

        expect(result).to include(site_seq: 1, since_prev_at_site: nil)
      end

      it "still numbers a val and a ts on the same line in one global seq" do
        visits = described_class.new
        visits.note(site)

        result = visits.note(site(type: "ts"))

        expect(result).to include(seq: 2)
      end
    end

    describe "since_prev_ts" do
      def stub_monotonic(time)
        allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(time)
      end

      it "is nil on the process's first checkpoint" do
        visits = described_class.new

        result = visits.note(site(type: "ts"), checkpoint: true)

        expect(result).to include(since_prev_ts: nil)
      end

      it "is the time since the previous checkpoint, at any site" do
        visits = described_class.new
        stub_monotonic(100.0)
        visits.note(site(type: "ts"), checkpoint: true)

        stub_monotonic(100.5)
        result = visits.note(site(type: "ts", file: "app/models/invoice.rb"), checkpoint: true)

        expect(result).to include(since_prev_ts: 0.5)
      end

      it "ignores calls that aren't checkpoints between two checkpoints" do
        visits = described_class.new
        stub_monotonic(100.0)
        visits.note(site(type: "ts"), checkpoint: true)
        stub_monotonic(100.2)
        visits.note(site(line: 11))

        stub_monotonic(100.5)
        result = visits.note(site(type: "ts", line: 12), checkpoint: true)

        expect(result).to include(since_prev_ts: 0.5)
      end

      it "is left off calls that aren't checkpoints" do
        visits = described_class.new
        visits.note(site(type: "ts"), checkpoint: true)

        result = visits.note(site(line: 11))

        expect(result).not_to have_key(:since_prev_ts)
      end

      it "doesn't count a call as a checkpoint for its site's type" do
        visits = described_class.new
        stub_monotonic(100.0)
        visits.note(site(type: "ts"), checkpoint: true)
        stub_monotonic(100.2)
        visits.note(site(type: "ts", line: 11))

        stub_monotonic(100.5)
        result = visits.note(site(type: "ts", line: 12), checkpoint: true)

        expect(result).to include(since_prev_ts: 0.5)
      end

      it "counts a call the caller says is a checkpoint, whatever its site's type" do
        visits = described_class.new
        stub_monotonic(100.0)
        visits.note(site(type: "ts"), checkpoint: true)

        stub_monotonic(100.5)
        result = visits.note(site(type: "val"), checkpoint: true)

        expect(result).to include(since_prev_ts: 0.5)
      end
    end
  end
end
