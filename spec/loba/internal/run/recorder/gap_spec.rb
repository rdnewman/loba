RSpec.describe Loba::Internal::Run::Recorder::Gap do
  def no_space = Errno::ENOSPC.new

  def sink_to(path) = Loba::Internal::Destination::Sink.new(path)

  describe ".new" do
    it "starts at the first record that couldn't be written" do
      gap = described_class.new(error: no_space, seq: 3)

      expect(gap.to_h).to eq(
        count: 1, first_seq: 3, last_seq: 3, error: "Errno::ENOSPC: No space left on device"
      )
    end
  end

  describe "#add" do
    it "counts a later record and extends the seq range, keeping the first error" do
      gap = described_class.new(error: no_space, seq: 3)

      gap.add(seq: 7)

      expect(gap.to_h).to eq(
        count: 2, first_seq: 3, last_seq: 7, error: "Errno::ENOSPC: No space left on device"
      )
    end
  end

  describe "#noted_on" do
    it "notes the gap on the record, as unwritten" do
      gap = described_class.new(error: no_space, seq: 3)

      noted = gap.noted_on({ seq: 4 })

      expect(noted).to eq(seq: 4, unwritten: gap.to_h)
    end

    # The gap qualifies the record's place in the run, so it comes right after
    # the record's seq and type, before anything that could make a line long.
    it "places the gap right after the record's seq and type" do
      gap = described_class.new(error: no_space, seq: 3)

      noted = gap.noted_on({ label: "after", type: "ts", seq: 4 })

      expect(noted.keys).to eq([:seq, :type, :unwritten, :label])
    end
  end

  describe "#summary" do
    it "names one record, the sink, and the error" do
      gap = described_class.new(error: no_space, seq: 3)

      expect(gap.summary(sink: sink_to("a.jsonl"))).to eq(
        "1 record couldn't be written to \"a.jsonl\" " \
        "(first error: Errno::ENOSPC: No space left on device)"
      )
    end

    it "counts several records, keeping the first error" do
      gap = described_class.new(error: no_space, seq: 3)
      gap.add(seq: 4)

      expect(gap.summary(sink: sink_to("a.jsonl"))).to eq(
        "2 records couldn't be written to \"a.jsonl\" " \
        "(first error: Errno::ENOSPC: No space left on device)"
      )
    end
  end
end
