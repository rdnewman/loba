RSpec.describe Loba::Internal::Run::Visits do
  def site(type: "val", file: "app/models/order.rb", line: 10)
    Loba::Internal::Site.new(type:, file:, line:)
  end

  describe "#note" do
    it "assigns seq 1 and site_seq 1 to a call site's first record" do
      visits = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)

      result = visits.note(site)

      expect(result).to eq(seq: 1, mono_time: 100.0, site_seq: 1, diff: nil)
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

    it "reports diff as the elapsed time since the previous record at the same site" do
      visits = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)
      visits.note(site)

      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.25)
      result = visits.note(site)

      expect(result).to include(diff: 0.25)
    end

    # A record's diff and since_prev_ts must equal the gap between the
    # mono_time values written on its lines, so the reading they're measured
    # from is the one written.
    it "reports the clock reading its timing was measured from" do
      visits = described_class.new
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.25)

      result = visits.note(site(type: "ts"))

      expect(result).to include(mono_time: 100.25)
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
      it "gives another file its own site_seq and diff" do
        visits = described_class.new
        visits.note(site)

        result = visits.note(site(file: "app/models/invoice.rb"))

        expect(result).to include(site_seq: 1, diff: nil)
      end

      it "gives another line in the same file its own site_seq and diff" do
        visits = described_class.new
        visits.note(site)

        result = visits.note(site(line: 11))

        expect(result).to include(site_seq: 1, diff: nil)
      end

      it "gives another record type on the same line its own site_seq and diff" do
        visits = described_class.new
        visits.note(site)

        result = visits.note(site(type: "ts"))

        expect(result).to include(site_seq: 1, diff: nil)
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

  describe "#flush" do
    # A site's cap is 500 records per window.
    def note_past_cap(visits, site, destination, skipped:)
      (500 + skipped).times { visits.note(site, destination:) }
    end

    it "writes the still-open window's true skipped count for a capped site" do
      visits = described_class.new
      sink = StringIO.new
      note_past_cap(visits, site, destination_to(sink), skipped: 8)

      visits.flush

      expect(JSON.parse(sink.string.lines.last)).to include(
        "type" => "val", "file" => "app/models/order.rb", "line" => 10,
        "suppressed" => true, "suppressed_count" => 8
      )
    end

    it "flushes every capped site independently, to each one's own sink", :aggregate_failures do
      visits = described_class.new
      order_sink = StringIO.new
      invoice_sink = StringIO.new
      invoice_site = site(file: "app/models/invoice.rb", line: 20)
      note_past_cap(visits, site, destination_to(order_sink), skipped: 1)
      note_past_cap(visits, invoice_site, destination_to(invoice_sink), skipped: 4)

      visits.flush

      order_flushed = JSON.parse(order_sink.string.lines.last)
      invoice_flushed = JSON.parse(invoice_sink.string.lines.last)
      expect(order_flushed).to include("file" => "app/models/order.rb", "suppressed_count" => 1)
      expect(invoice_flushed)
        .to include("file" => "app/models/invoice.rb", "suppressed_count" => 4)
    end

    it "numbers the records it writes after the visits' last seq" do
      visits = described_class.new
      sink = StringIO.new
      note_past_cap(visits, site, destination_to(sink), skipped: 1)

      visits.flush

      expect(JSON.parse(sink.string.lines.last)).to include("seq" => 501)
    end

    it "lets another thread note a new site while it flushes", :aggregate_failures do
      visits = described_class.new
      note_past_cap(visits, site, destination_to(StringIO.new), skipped: 1)
      flushing = Queue.new
      # Holds the flush partway through its sites.
      allow(Loba::Internal::Records::Suppression)
        .to receive(:fields).and_wrap_original do |original, **options|
          flushing << true
          sleep 0.05
          original.call(**options)
        end
      flusher = Thread.new { visits.flush }
      held = flushing.pop(timeout: 5)

      noter = Thread.new { visits.note(site(file: "app/models/invoice.rb", line: 20)) }

      expect(held).to be true
      expect { [flusher, noter].each(&:join) }.not_to raise_error
    end

    it "writes nothing for a site under its cap" do
      visits = described_class.new
      sink = StringIO.new
      visits.note(site, destination: destination_to(sink))

      visits.flush

      expect(sink.string).to be_empty
    end

    it "warns rather than raising when a capped site's sink was closed" do
      visits = described_class.new
      sink = StringIO.new
      note_past_cap(visits, site, destination_to(sink), skipped: 1)
      sink.close

      expect { visits.flush }.to output(/loba: couldn't write a record/).to_stderr
    end
  end
end
