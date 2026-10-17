require "stringio"

RSpec.describe Lba::Internal::Run::WriteFailures do
  def no_space = Errno::ENOSPC.new

  def sink_to(path) = Lba::Internal::Destination::Sink.new(path)

  describe "#report" do
    it "warns on $stderr about the first failure, naming the sink and the error" do
      failures = described_class.new
      error = Errno::EACCES.new("sink.jsonl")

      expect { failures.report(sink: sink_to("sink.jsonl"), error:, seq: 3) }.to output(
        "lba: couldn't write a record to \"sink.jsonl\" " \
        "(Errno::EACCES: Permission denied - sink.jsonl); " \
        "later write failures in this process won't be reported\n"
      ).to_stderr
    end

    it "stays quiet about later failures", :aggregate_failures do
      failures = described_class.new
      expect { failures.report(sink: sink_to("sink.jsonl"), error: no_space, seq: 3) }
        .to output.to_stderr

      expect { failures.report(sink: sink_to("sink.jsonl"), error: no_space, seq: 4) }
        .not_to output.to_stderr
    end
  end

  describe "#unwritten" do
    it "is the sink's unwritten records: their count, seq range, and first error" do
      failures = described_class.new
      allow(failures).to receive(:warn)
      failures.report(sink: sink_to("a.jsonl"), error: no_space, seq: 3)
      failures.report(sink: sink_to("a.jsonl"), error: Errno::EACCES.new, seq: 4)

      expect(failures.unwritten(sink_to("a.jsonl")).to_h).to eq(
        count: 2, first_seq: 3, last_seq: 4, error: "Errno::ENOSPC: No space left on device"
      )
    end

    it "keeps each sink's unwritten records apart" do
      failures = described_class.new
      allow(failures).to receive(:warn)
      failures.report(sink: sink_to("a.jsonl"), error: no_space, seq: 3)

      expect(failures.unwritten(sink_to("b.jsonl"))).to be_nil
    end
  end

  describe "#forget_unwritten" do
    it "forgets the sink's unwritten records, once a later record has noted them" do
      failures = described_class.new
      allow(failures).to receive(:warn)
      failures.report(sink: sink_to("a.jsonl"), error: no_space, seq: 3)

      failures.forget_unwritten(sink_to("a.jsonl"))

      expect(failures.unwritten(sink_to("a.jsonl"))).to be_nil
    end
  end

  describe "#summarize" do
    it "reports each sink's records that were never written, one line per sink" do
      failures = described_class.new
      allow(failures).to receive(:warn)
      failures.report(sink: sink_to("a.jsonl"), error: no_space, seq: 3)
      failures.report(sink: sink_to("a.jsonl"), error: no_space, seq: 4)
      failures.report(sink: sink_to("b.jsonl"), error: Errno::EACCES.new, seq: 5)
      allow(failures).to receive(:warn).and_call_original

      expect { failures.summarize }.to output(
        "lba: 2 records couldn't be written to \"a.jsonl\" " \
        "(first error: Errno::ENOSPC: No space left on device)\n" \
        "lba: 1 record couldn't be written to \"b.jsonl\" " \
        "(first error: Errno::EACCES: Permission denied)\n"
      ).to_stderr
    end

    it "reports nothing for a sink whose gap was since noted" do
      failures = described_class.new
      allow(failures).to receive(:warn)
      failures.report(sink: sink_to("a.jsonl"), error: no_space, seq: 3)
      failures.forget_unwritten(sink_to("a.jsonl"))
      allow(failures).to receive(:warn).and_call_original

      expect { failures.summarize }.not_to output.to_stderr
    end
  end
end
