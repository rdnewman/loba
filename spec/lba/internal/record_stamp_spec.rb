RSpec.describe Lba::Internal::RecordStamp do
  describe ".fields" do
    it "stamps the schema version, this process's run, and the given seq and type" do
      stamp = described_class.fields(seq: 7, type: "val")

      expect(stamp)
        .to include(schema: 1, run_id: Lba::Internal::Run.current.id, seq: 7, type: "val")
    end

    it "records the wall-clock time and the monotonic clock reading", :aggregate_failures do
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC).and_return(12_345.678)

      stamp = described_class.fields(seq: 1, type: "val")

      expect(stamp[:mono_time]).to eq(12_345.678)
      expect(stamp[:wall_time]).to be_within(5).of(Time.now.to_f)
    end

    it "records a given monotonic clock reading instead of reading the clock" do
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(999.0)

      stamp = described_class.fields(seq: 1, type: "ts", mono_time: 100.25)

      expect(stamp[:mono_time]).to eq(100.25)
    end

    it "has only those fields" do
      stamp = described_class.fields(seq: 1, type: "val")

      expect(stamp.keys).to contain_exactly(:schema, :run_id, :seq, :type, :wall_time, :mono_time)
    end
  end
end
