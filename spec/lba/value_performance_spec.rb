require "stringio"

# The Phase 4 runtime-overhead hard gate (see eager-forging-wave.md): loba's
# original design goal -- keep the instrumented call site thin -- carries
# over here, and matters even more for Lba.ts specifically, whose whole job
# is an honest elapsed-time diff. A tracing tool with real or inconsistent
# overhead corrupts the very thing it measures. This exercises the full
# Lba.val path for real (CallerBinding reflection, CallSiteTracker,
# Settings, Serialization, Writer) -- unlike serialization_performance_spec.rb,
# which scoped to just Serialization ahead of this fuller gate existing.
RSpec.describe Lba, ".val" do
  describe "performance", :aggregate_failures do
    def elapsed
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    end

    # Real CallSiteTracker.current behavior (real seq/site_seq/cap accounting)
    # without registering a real at_exit hook against this test process.
    before { safe_call_site_tracker_current }
    after { Lba::Internal::CallSiteTracker.instance_variable_set(:@current, nil) }

    # CallSiteTracker's default cap is 500 records per 60-second window, and
    # Lba.val has no public cap:/window: override -- this must stay
    # comfortably under that per call site, or later iterations would
    # silently get suppressed (and artificially fast) partway through.
    it "adds only a small, explicit amount of overhead over a no-op baseline" do
      iterations = 300
      sink = StringIO.new

      baseline = elapsed { iterations.times { Process.clock_gettime(Process::CLOCK_MONOTONIC) } }
      measured = elapsed { iterations.times { described_class.val(42, sink:) } }

      overhead_per_call = (measured - baseline) / iterations

      expect(overhead_per_call).to be < 0.005 # 5ms/call -- plan's "low-single-digit milliseconds"
    end

    it "has consistent, low-variance overhead across many calls" do
      iterations = 300
      sink = StringIO.new
      timings = Array.new(iterations) { elapsed { described_class.val(42, sink:) } }.sort
      mean = timings.sum / timings.size
      p99 = timings[(iterations * 0.99).to_i]

      # p99, not max: a single call can hit a GC pause or scheduler blip
      # unrelated to Lba.val itself.
      expect(p99).to be < [mean * 10, 0.005].max
    end
  end

  # Speed and memory are sometimes traded off against each other -- a fast
  # implementation that quietly retains memory is its own real cost,
  # especially for a tool meant to run continuously inside a live process.
  describe "memory", :aggregate_failures do
    before { safe_call_site_tracker_current }
    after { Lba::Internal::CallSiteTracker.instance_variable_set(:@current, nil) }

    it "allocates only a bounded, explicit number of objects per call" do
      iterations = 300
      sink = StringIO.new

      GC.disable
      before = GC.stat[:total_allocated_objects]
      iterations.times { described_class.val(42, sink:) }
      after = GC.stat[:total_allocated_objects]
      GC.enable

      objects_per_call = (after - before) / iterations.to_f

      # ~1045 measured directly inside this actual spec environment -- NOT
      # representative of bare production allocation cost. Verified
      # empirically: RSpec itself, merely loaded and running inside an
      # example, roughly triples a bare script's allocation count (197.8 ->
      # 573.9, no mocks involved), and this file's own mocking
      # (verify_partial_doubles, the CallSiteTracker stub) inflates it
      # further. That inflation is a stable property of the test harness,
      # not of Lba.val, so the useful signal here is a regression in this
      # number over time, not its absolute value against real-world use.
      expect(objects_per_call).to be < 2000
    end

    # rubocop:disable-next RSpec/ExampleLength -- each batch needs its own
    # physical call-site line (see the comment inside); collapsing them into
    # a loop would defeat the point.
    it "does not retain memory across repeated batches of calls" do
      batch_size = 300
      sink = StringIO.new

      # Each batch calls Lba.val from its own physical line, on purpose --
      # they share a helper method's line, they'd share one site key and
      # cross the 500-call cap partway through, silently switching the
      # later batches over to the (much cheaper) suppressed path instead of
      # each genuinely exercising the real one.
      reset = lambda do
        sink.truncate(0)
        sink.rewind
        GC.start
      end

      # First batch warms up any one-time setup cost (autoloaded constants,
      # etc.) so it doesn't get mistaken for a growth trend below.
      batch_size.times { described_class.val(42, sink:) }
      reset.call
      after_first_batch = GC.stat[:heap_live_slots]

      batch_size.times { described_class.val(42, sink:) }
      reset.call
      batch_size.times { described_class.val(42, sink:) }
      reset.call
      batch_size.times { described_class.val(42, sink:) }
      reset.call
      after_later_batches = GC.stat[:heap_live_slots]

      # Live heap size after a full GC should be flat across batches, not
      # grow with call count -- growth here would mean something is being
      # retained (a reference held onto) rather than becoming garbage.
      expect(after_later_batches - after_first_batch).to be < 500
    end
  end
end
