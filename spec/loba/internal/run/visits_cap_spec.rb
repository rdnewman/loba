RSpec.describe Loba::Internal::Run::Visits do
  describe "write-time cap" do
    subject(:visits) { described_class.new }

    # A site's cap is 500 records per 60-second window.
    let(:cap) { 500 }
    let(:discarding_destination) { destination_to(instance_double(IO, write: nil, flush: nil)) }

    def site(type: "val", file: "app/models/order.rb", line: 10)
      Loba::Internal::Site.new(type:, file:, line:)
    end

    def stub_monotonic(time)
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(time)
    end

    def note_past_cap(site, destination, suppressed:)
      (cap + suppressed).times { visits.note(site, destination:) }
    end

    def record_checkpoint(site)
      visits.note(site, destination: discarding_destination, checkpoint: true)
    end

    context "when a call crosses the cap" do
      it "suppresses it without writing anything", :aggregate_failures do
        sink = instance_double(IO, write: nil, flush: nil)
        destination = destination_to(sink)
        cap.times { visits.note(site, destination:) }

        result = visits.note(site, destination:)

        expect(result).to eq(:suppressed)
        expect(sink).not_to have_received(:write)
      end
    end

    context "when a site is capped" do
      it "caps a ts on the same line separately from the capped val" do
        note_past_cap(site, discarding_destination, suppressed: 1)

        result = visits.note(site(type: "ts"), destination: discarding_destination)

        expect(result).to include(site_seq: 1)
      end

      it "doesn't advance since_prev_ts on skipped calls" do
        stub_monotonic(100.0)
        cap.times { record_checkpoint(site(type: "ts")) }
        stub_monotonic(100.3)
        record_checkpoint(site(type: "ts"))

        stub_monotonic(100.5)
        result = record_checkpoint(site(type: "ts", line: 20))

        expect(result).to include(since_prev_ts: 0.5)
      end
    end

    context "when a capped site's window runs out" do
      it "writes exactly one suppression record, with the true suppressed count",
         :aggregate_failures do
        sink = StringIO.new
        destination = destination_to(sink)
        window_start = 1_000.0
        stub_monotonic(window_start)
        note_past_cap(site, destination, suppressed: 7)
        stub_monotonic(window_start + 60)

        visits.note(site, destination:)

        lines = sink.string.lines
        expect(lines.size).to eq(1)
        expect(JSON.parse(lines.first)).to include(
          "type" => "val", "file" => "app/models/order.rb", "line" => 10,
          "suppressed" => true, "suppressed_count" => 7
        )
      end

      it "uses up no numbers on skipped calls, giving the suppression record the next seq",
         :aggregate_failures do
        sink = StringIO.new
        destination = destination_to(sink)
        window_start = 1_000.0
        stub_monotonic(window_start)
        note_past_cap(site, destination, suppressed: 4)
        stub_monotonic(window_start + 60)

        result = visits.note(site, destination:)

        expect(JSON.parse(sink.string.lines.last)).to include("seq" => cap + 1)
        expect(result).to include(seq: cap + 2, site_seq: cap + 1)
      end

      it "times since_prev_ts from the previous checkpoint, " \
         "not the suppression record written just before it" do
        stub_monotonic(100.0)
        (cap + 1).times { record_checkpoint(site(type: "ts")) }

        stub_monotonic(170.0)
        result = record_checkpoint(site(type: "ts"))

        expect(result).to include(since_prev_ts: 70.0)
      end
    end

    describe "#flush" do
      it "writes the still-open window's true suppressed count" do
        sink = StringIO.new
        note_past_cap(site, destination_to(sink), suppressed: 8)

        visits.flush

        expect(JSON.parse(sink.string.lines.last)).to include(
          "type" => "val", "file" => "app/models/order.rb", "line" => 10,
          "suppressed" => true, "suppressed_count" => 8
        )
      end

      it "flushes every capped site independently, to each one's own sink", :aggregate_failures do
        order_sink = StringIO.new
        invoice_sink = StringIO.new
        invoice_site = site(file: "app/models/invoice.rb", line: 20)
        note_past_cap(site, destination_to(order_sink), suppressed: 1)
        note_past_cap(invoice_site, destination_to(invoice_sink), suppressed: 4)

        visits.flush

        order_flushed = JSON.parse(order_sink.string.lines.last)
        invoice_flushed = JSON.parse(invoice_sink.string.lines.last)
        expect(order_flushed).to include("file" => "app/models/order.rb", "suppressed_count" => 1)
        expect(invoice_flushed)
          .to include("file" => "app/models/invoice.rb", "suppressed_count" => 4)
      end

      it "numbers the records it writes after the visits' last seq" do
        sink = StringIO.new
        note_past_cap(site, destination_to(sink), suppressed: 1)

        visits.flush

        expect(JSON.parse(sink.string.lines.last)).to include("seq" => cap + 1)
      end

      it "lets another thread note a new site while it flushes", :aggregate_failures do
        note_past_cap(site, destination_to(StringIO.new), suppressed: 1)
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
        sink = StringIO.new
        visits.note(site, destination: destination_to(sink))

        visits.flush

        expect(sink.string).to be_empty
      end
    end
  end
end
