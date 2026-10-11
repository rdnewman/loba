RSpec.describe Lba::Internal::CallSiteTracker do
  describe ".current" do
    let(:cap) { 500 }

    after { reset_current(described_class) }

    it "registers the shutdown flush exactly once, the first time it's created" do
      hooks = stub_call_site_tracker_at_exit

      described_class.current
      described_class.current

      expect(hooks.size).to eq(1)
    end

    context "when its shutdown hook runs" do
      it "writes the still-open window's true suppressed count for a capped site" do
        hooks = stub_call_site_tracker_at_exit
        tracker = described_class.current
        site = { type: "val", file: "app/models/order.rb", line: 10 }
        sink = StringIO.new

        (cap + 8).times { tracker.record(**site, sink:) }

        hooks.first.call

        flushed = JSON.parse(sink.string.lines.last)
        expect(flushed).to include(
          "type" => "val", "file" => "app/models/order.rb", "line" => 10,
          "suppressed" => true, "suppressed_count" => 8
        )
      end

      it "flushes every capped site independently, to each one's own sink", :aggregate_failures do
        hooks = stub_call_site_tracker_at_exit
        tracker = described_class.current
        order_site = { type: "val", file: "app/models/order.rb", line: 10 }
        invoice_site = { type: "val", file: "app/models/invoice.rb", line: 20 }
        order_sink = StringIO.new
        invoice_sink = StringIO.new

        (cap + 1).times { tracker.record(**order_site, sink: order_sink) }
        (cap + 4).times { tracker.record(**invoice_site, sink: invoice_sink) }

        hooks.first.call

        order_flushed = JSON.parse(order_sink.string.lines.last)
        invoice_flushed = JSON.parse(invoice_sink.string.lines.last)
        expect(order_flushed).to include("file" => "app/models/order.rb", "suppressed_count" => 1)
        expect(invoice_flushed)
          .to include("file" => "app/models/invoice.rb", "suppressed_count" => 4)
      end

      it "warns rather than raising when a capped site's sink was closed before exit" do
        capture_at_exit_hooks(Lba::Internal::WriteFailures)
        hooks = stub_call_site_tracker_at_exit
        tracker = described_class.current
        site = { type: "val", file: "app/models/order.rb", line: 10 }
        sink = StringIO.new
        (cap + 1).times { tracker.record(**site, sink:) }
        sink.close

        expect { hooks.first.call }.to output(/lba: couldn't write a record/).to_stderr
      ensure
        reset_current(Lba::Internal::WriteFailures)
      end
    end

    context "when the process forks after the hook is registered" do
      it "writes nothing when the child runs the hook it inherited" do
        hooks = stub_call_site_tracker_at_exit
        tracker = described_class.current
        site = { type: "val", file: "app/models/order.rb", line: 10 }
        sink = StringIO.new
        (cap + 1).times { tracker.record(**site, sink:) }

        written_in_child = in_forked_child do
          hooks.first.call
          sink.string
        end

        expect(written_in_child).to be_empty
      end
    end
  end
end
