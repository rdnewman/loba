RSpec.describe Loba::Internal::Records::Stamp do
  describe ".fields" do
    it "stamps the schema version and this process's run" do
      stamp = described_class.fields

      expect(stamp).to include(schema: 1, run_id: Loba::Internal::Run.current.id)
    end

    it "records the wall-clock time and the monotonic clock reading", :aggregate_failures do
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(12_345.678)

      stamp = described_class.fields

      expect(stamp[:mono_time]).to eq(12_345.678)
      expect(stamp[:wall_time]).to be_within(5).of(Time.now.to_f)
    end

    it "records a given monotonic clock reading instead of reading the clock" do
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(999.0)

      stamp = described_class.fields(mono_time: 100.25)

      expect(stamp[:mono_time]).to eq(100.25)
    end

    it "has only those fields" do
      stamp = described_class.fields

      expect(stamp.keys).to contain_exactly(:wall_time, :mono_time, :run_id, :schema)
    end
  end
end
