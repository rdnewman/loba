# Serialization's own cost, apart from the rest of Lba.value.
#
# Timing checks vary by machine, so they're tagged :performance and run only
# with `--tag performance`. The allocation check doesn't, so it runs by default.
RSpec.describe Lba::Internal::Serialization do
  describe ".serialize" do
    def elapsed
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    end

    def structure_with(breadth)
      Array.new(breadth) { Array.new(5) { Array.new(5) { "leaf" } } }
    end

    # Every Array and every leaf counts as one value, matching what the walk
    # visits.
    def value_count(value)
      if value.is_a?(Array)
        1 + value.sum { |entry| value_count(entry) }
      else
        1
      end
    end

    def allocations_per_value(breadth)
      structure = structure_with(breadth)

      allocations = allocations_during { described_class.serialize(value: structure) }

      allocations / value_count(structure).to_f
    end

    it "adds only a small, explicit amount of overhead over a no-op baseline", :performance do
      iterations = 10_000

      baseline = elapsed { iterations.times { Process.clock_gettime(Process::CLOCK_MONOTONIC) } }
      measured = elapsed { iterations.times { described_class.serialize(value: 42) } }

      overhead_per_call = (measured - baseline) / iterations
      expect(overhead_per_call).to be < 0.0001 # 100 microseconds/call, a generous ceiling
    end

    # p99, not max: a single call can hit a GC pause or scheduler blip
    # unrelated to Serialization itself.
    it "keeps the 99th-percentile call under 100 microseconds", :performance do
      iterations = 1_000

      timings = Array.new(iterations) { elapsed { described_class.serialize(value: 42) } }.sort

      p99 = timings[(iterations * 0.99).to_i]
      expect(p99).to be < 0.0001
    end

    # Total cost grows with the number of values, as expected. Cost per value
    # must not, or some step is re-walking or re-copying what it visited.
    it "does not allocate more per value as the value grows" do
      small = allocations_per_value(10)
      large = allocations_per_value(40)

      expect(large).to be <= small
    end

    # An entry that can't be rendered raises and rescues an exception and adds
    # an entry to :errors, so it costs more than one rendered as text; these
    # bound how much more, against the same number of renderable objects.
    context "when entries can't be rendered" do
      def renderable(count) = Array.new(count) { Object.new }

      def unrenderable(count) = Array.new(count) { BasicObject.new }

      def allocations_for(value) = allocations_during { described_class.serialize(value:) }

      # Alternates the two runs so order can't skew them, and keeps the fastest
      # of each, since noise only ever adds time.
      def fastest_times(first, second)
        first_times = []
        second_times = []
        5.times do
          first_times << elapsed { 20.times { described_class.serialize(value: first) } }
          second_times << elapsed { 20.times { described_class.serialize(value: second) } }
        end

        [first_times.min, second_times.min]
      end

      it "allocates less than 3 times what renderable entries do" do
        failing = allocations_for(unrenderable(50))
        rendered = allocations_for(renderable(50))

        expect(failing).to be < rendered * 3
      end

      it "does not allocate more per entry as the number of failures grows" do
        small = allocations_for(unrenderable(10)) / 10.0
        large = allocations_for(unrenderable(40)) / 40.0

        expect(large).to be <= small
      end

      it "takes less than 3 times as long as renderable entries", :performance do
        failing, rendered = fastest_times(unrenderable(50), renderable(50))

        expect(failing).to be < rendered * 3
      end
    end
  end
end
