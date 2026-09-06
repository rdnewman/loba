# A scoped baseline for Serializer specifically, ahead of the full Lba.val
# overhead gate planned for Phase 4 (see eager-forging-wave.md). Serializer
# has since gained recursive depth-bounding and still has size-truncation to
# add -- a tracing tool with real or inconsistent overhead corrupts the very
# thing it measures, worst for Lba.ts, whose whole job is an honest elapsed
# time. This "before" baseline is the only way to notice that complexity
# adding overhead.
RSpec.describe Lba::Internal::Serializer do
  describe "performance", :aggregate_failures do
    def elapsed
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    end

    it "adds only a small, explicit amount of overhead over a no-op baseline" do
      iterations = 10_000

      baseline = elapsed { iterations.times { Process.clock_gettime(Process::CLOCK_MONOTONIC) } }
      measured = elapsed { iterations.times { described_class.serialize(42) } }

      overhead_per_call = (measured - baseline) / iterations

      expect(overhead_per_call).to be < 0.0001 # 100 microseconds/call, a generous ceiling
    end

    it "has consistent, low-variance overhead across many calls" do
      iterations = 1_000
      timings = Array.new(iterations) { elapsed { described_class.serialize(42) } }.sort
      mean = timings.sum / timings.size
      p99 = timings[(iterations * 0.99).to_i]

      # p99, not max: a single call can hit a GC pause or scheduler blip
      # unrelated to Serializer itself. p99 reflects typical consistency
      # without being sensitive to one-off OS noise the way a raw max is.
      expect(p99).to be < [mean * 10, 0.0001].max
    end
  end
end
