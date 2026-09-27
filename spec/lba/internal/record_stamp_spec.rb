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

    # Records are read raw as well as parsed, so every record opens the same way.
    it "puts its fields in a fixed order" do
      stamp = described_class.fields(seq: 1, type: "val")

      expect(stamp.keys).to eq([:schema, :run_id, :seq, :type, :wall_time, :mono_time])
    end
  end
end
