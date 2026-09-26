require "securerandom"

RSpec.describe Lba::Internal::Run do
  describe "#id" do
    it "combines a UTC timestamp, the process id, and a random hex suffix" do
      allow(Time).to receive(:now).and_return(Time.utc(2026, 8, 30, 14, 30, 12))
      allow(Process).to receive(:pid).and_return(4242)
      allow(SecureRandom).to receive(:hex).with(2).and_return("ab12")

      run = described_class.new

      expect(run.id).to eq("20260830T143012Z-4242-ab12")
    end

    it "memoizes the id across repeated calls" do
      run = described_class.new
      first_id = run.id

      allow(SecureRandom).to receive(:hex).and_return("ffff")

      expect(run.id).to eq(first_id)
    end
  end

  describe "#started_at" do
    it "returns the monotonic clock reading taken at construction" do
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(12_345.678)

      run = described_class.new

      expect(run.started_at).to eq(12_345.678)
    end

    it "memoizes started_at across repeated calls" do
      run = described_class.new
      first_started_at = run.started_at

      allow(Process).to receive(:clock_gettime).and_return(99_999.0)

      expect(run.started_at).to eq(first_started_at)
    end
  end

  describe ".current" do
    after { reset_current(described_class) }

    it "returns a Run instance" do
      expect(described_class.current).to be_a(described_class)
    end

    it "memoizes the same instance across repeated calls" do
      expect(described_class.current).to equal(described_class.current)
    end

    context "when the process forks after .current is memoized" do
      it "gives the child its own run, identified by the child's pid", :aggregate_failures do
        parent_run_id = described_class.current.id

        child = in_forked_child { { pid: Process.pid, run_id: described_class.current.id } }

        expect(child[:run_id]).not_to eq(parent_run_id)
        expect(child[:run_id]).to include("-#{child[:pid]}-")
      end
    end
  end
end
