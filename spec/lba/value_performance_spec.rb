require "stringio"

# Keeps the full Lba.val path cheap enough not to change the code it traces.
#
# Timing checks vary by machine, so they're tagged :performance and run only
# with `--tag performance`. Memory checks don't, so they run by default.
#
# Each example stays under CallSiteTracker's cap of 500 calls per site per
# minute. Past it, calls take the cheaper suppressed path and skew the result.
RSpec.describe Lba, ".val" do
  after { reset_current(Lba::Internal::CallSiteTracker) }

  def elapsed
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  end

  # Empties the sink, whose output is expected, runs a full GC, and returns
  # the live heap slot count.
  def clear_and_collect(sink)
    sink.truncate(0)
    sink.rewind
    GC.start
    GC.stat[:heap_live_slots]
  end

  it "adds only a small, explicit amount of overhead over a no-op baseline", :performance do
    stub_call_site_tracker_at_exit
    iterations = 300
    sink = StringIO.new

    baseline = elapsed { iterations.times { Process.clock_gettime(Process::CLOCK_MONOTONIC) } }
    measured = elapsed { iterations.times { described_class.val(42, sink:) } }

    overhead_per_call = (measured - baseline) / iterations

    # A tripwire for order-of-magnitude regressions. Typical overhead is under
    # a tenth of this.
    expect(overhead_per_call).to be < 0.005
  end

  # Bounds the noise Lba.val adds to an elapsed-time diff, which Lba.ts
  # reports. GC pauses set the tail and cost the same wall time on any
  # machine, so the bound is absolute and loose, not a multiple of the mean.
  it "keeps the 99th-percentile call under 10ms", :performance do
    stub_call_site_tracker_at_exit
    iterations = 300
    sink = StringIO.new

    timings = Array.new(iterations) { elapsed { described_class.val(42, sink:) } }.sort

    p99 = timings[(iterations * 0.99).to_i]
    expect(p99).to be < 0.010
  end

  def at_stack_depth(depth, &)
    if depth.zero?
      yield
    else
      at_stack_depth(depth - 1, &)
    end
  end

  # Alternates shallow and deep runs so run order can't skew the comparison,
  # and keeps the fastest of each, since noise only ever adds time. Makes 400
  # calls in all, under the cap for a single call site.
  def added_cost_at_depth(depth, &)
    shallow_times = []
    deep_times = []
    5.times do
      shallow_times << elapsed { 40.times(&) }
      deep_times << elapsed { at_stack_depth(depth) { 40.times(&) } }
    end

    deep_times.min - shallow_times.min
  end

  # RubyVM::DebugInspector.open snapshots the whole stack, so its cost grows
  # with depth, and Rails stacks run deep. Lba.val should pay that about once
  # per call, not once per field it reads.
  it "grows with stack depth about as much as one stack snapshot", :performance do
    stub_call_site_tracker_at_exit
    depth = 200
    sink = StringIO.new

    one_snapshot = added_cost_at_depth(depth) do
      RubyVM::DebugInspector.open(&:backtrace_locations)
    end
    one_val = added_cost_at_depth(depth) { described_class.val(42, sink:) }

    expect(one_val / one_snapshot).to be < 2.0
  end

  # Each stack snapshot allocates an object per frame, so this also depends on
  # stack depth, which RSpec adds to. The bound catches a regression but isn't
  # real-world cost. A call allocates about 200 here.
  it "allocates only a bounded, explicit number of objects per call" do
    stub_call_site_tracker_at_exit
    iterations = 300
    sink = StringIO.new

    allocations = allocations_during { iterations.times { described_class.val(42, sink:) } }

    expect(allocations / iterations.to_f).to be < 500
  end

  # Retained memory is a real cost for a tool that runs inside a live process.
  #
  # Each batch has its own line, and so its own site key; sharing one would
  # cross the cap. The first batch absorbs one-time setup, such as
  # autoloading, so it isn't mistaken for growth.
  it "does not retain memory across repeated batches of calls" do
    stub_call_site_tracker_at_exit
    batch_size = 300
    sink = StringIO.new

    batch_size.times { described_class.val(42, sink:) }
    after_first_batch = clear_and_collect(sink)
    batch_size.times { described_class.val(42, sink:) }
    clear_and_collect(sink)
    batch_size.times { described_class.val(42, sink:) }
    clear_and_collect(sink)
    batch_size.times { described_class.val(42, sink:) }
    after_later_batches = clear_and_collect(sink)

    # Growth across batches would mean something holds references it should
    # let go.
    expect(after_later_batches - after_first_batch).to be < 500
  end
end
