RSpec.describe Lba::Internal::CallSiteTracker do
  subject(:tracker) { described_class.new }

  let(:sink) { instance_double(IO, write: nil, flush: nil) }
  let(:site_key) { "app/models/order.rb:10" }
  let(:invoice_key) { "app/models/invoice.rb:20" }

  # Stubbing out Kernel#at_exit (rather than letting it really register) keeps
  # a stray hook from surviving into the rest of the test suite and firing
  # against stale doubles when the real rspec process exits.
  def capture_at_exit_hooks(on:)
    hooks = []
    allow(on).to receive(:at_exit) { |&block| hooks << block }
    hooks
  end

  describe "running the shutdown flush" do
    it "writes the still-open window's true suppressed count for a capped site" do
      sink = StringIO.new
      hooks = capture_at_exit_hooks(on: tracker)
      tracker.send(:register_at_exit!)

      5.times { |i| tracker.record(site_key, value: i, sink:, cap: 5) }
      8.times { |i| tracker.record(site_key, value: i, sink:, cap: 5) }

      hooks.first.call

      flushed = JSON.parse(sink.string.lines.last)
      expect(flushed).to include("site" => site_key, "suppressed" => true, "suppressed_count" => 8)
    end

    it "flushes every capped site independently, to each one's own sink", :aggregate_failures do
      order_sink = StringIO.new
      invoice_sink = StringIO.new
      hooks = capture_at_exit_hooks(on: tracker)
      tracker.send(:register_at_exit!)

      6.times { |i| tracker.record(site_key, value: i, sink: order_sink, cap: 5) }
      9.times { |i| tracker.record(invoice_key, value: i, sink: invoice_sink, cap: 5) }

      hooks.first.call

      order_flushed = JSON.parse(order_sink.string.lines.last)
      invoice_flushed = JSON.parse(invoice_sink.string.lines.last)
      expect(order_flushed).to include("site" => site_key, "suppressed_count" => 1)
      expect(invoice_flushed).to include("site" => invoice_key, "suppressed_count" => 4)
    end

    it "does not write anything for a site that never crossed its cap" do
      invoice_sink = instance_double(IO, write: nil, flush: nil)
      hooks = capture_at_exit_hooks(on: tracker)
      tracker.send(:register_at_exit!)

      4.times { |i| tracker.record(site_key, value: i, sink:, cap: 5) }
      7.times { |i| tracker.record(invoice_key, value: i, sink: invoice_sink, cap: 5) }

      hooks.first.call

      expect(sink).not_to have_received(:write)
    end
  end

  describe ".current" do
    after { described_class.instance_variable_set(:@current, nil) }

    it "registers the shutdown flush exactly once, the first time it's created" do
      preconstructed = described_class.new
      hooks = capture_at_exit_hooks(on: preconstructed)
      allow(described_class).to receive(:new).and_return(preconstructed)

      described_class.current
      described_class.current

      expect(hooks.size).to eq(1)
    end

    it "flushes the memoized instance's own suppressed sites when the hook runs" do
      preconstructed = described_class.new
      hooks = capture_at_exit_hooks(on: preconstructed)
      allow(described_class).to receive(:new).and_return(preconstructed)
      sink = StringIO.new

      current = described_class.current
      6.times { |i| current.record(site_key, value: i, sink:, cap: 5) }

      hooks.first.call

      flushed = JSON.parse(sink.string.lines.last)
      expect(flushed).to include("site" => site_key, "suppressed_count" => 1)
    end
  end
end
