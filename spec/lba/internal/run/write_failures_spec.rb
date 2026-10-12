require "stringio"

RSpec.describe Lba::Internal::Run::WriteFailures do
  after { reset_current(described_class) }

  def no_space = Errno::ENOSPC.new

  describe "#report" do
    it "warns on $stderr about the first failure, naming the sink and the error" do
      failures = described_class.new
      error = Errno::EACCES.new("sink.jsonl")

      expect { failures.report(sink: "sink.jsonl", error:, seq: 3) }.to output(
        "lba: couldn't write a record to \"sink.jsonl\" " \
        "(Errno::EACCES: Permission denied - sink.jsonl); " \
        "later write failures in this process won't be reported\n"
      ).to_stderr
    end

    it "stays quiet about later failures", :aggregate_failures do
      failures = described_class.new
      expect { failures.report(sink: "sink.jsonl", error: no_space, seq: 3) }.to output.to_stderr

      expect { failures.report(sink: "sink.jsonl", error: no_space, seq: 4) }
        .not_to output.to_stderr
    end
  end

  describe "#unwritten" do
    it "is the sink's unwritten records: their count, seq range, and first error" do
      failures = described_class.new
      allow(failures).to receive(:warn)
      failures.report(sink: "a.jsonl", error: no_space, seq: 3)
      failures.report(sink: "a.jsonl", error: Errno::EACCES.new, seq: 4)

      expect(failures.unwritten("a.jsonl")).to eq(
        count: 2, first_seq: 3, last_seq: 4, error: "Errno::ENOSPC: No space left on device"
      )
    end

    it "keeps each sink's unwritten records apart" do
      failures = described_class.new
      allow(failures).to receive(:warn)
      failures.report(sink: "a.jsonl", error: no_space, seq: 3)

      expect(failures.unwritten("b.jsonl")).to be_nil
    end
  end

  describe "#forget_unwritten" do
    it "forgets the sink's unwritten records, once a later record has noted them" do
      failures = described_class.new
      allow(failures).to receive(:warn)
      failures.report(sink: "a.jsonl", error: no_space, seq: 3)

      failures.forget_unwritten("a.jsonl")

      expect(failures.unwritten("a.jsonl")).to be_nil
    end
  end

  describe "#summarize" do
    it "reports each sink's records that were never written, one line per sink" do
      failures = described_class.new
      allow(failures).to receive(:warn)
      failures.report(sink: "a.jsonl", error: no_space, seq: 3)
      failures.report(sink: "a.jsonl", error: no_space, seq: 4)
      failures.report(sink: "b.jsonl", error: Errno::EACCES.new, seq: 5)
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
      failures.report(sink: "a.jsonl", error: no_space, seq: 3)
      failures.forget_unwritten("a.jsonl")
      allow(failures).to receive(:warn).and_call_original

      expect { failures.summarize }.not_to output.to_stderr
    end
  end

  describe ".existing" do
    it "is nil while no failure has created the process's instance" do
      expect(described_class.existing).to be_nil
    end

    it "is the process's instance once one exists" do
      current = described_class.current

      expect(described_class.existing).to equal(current)
    end
  end

  describe ".current" do
    it "memoizes the same instance across repeated calls" do
      expect(described_class.current).to equal(described_class.current)
    end

    it "registers no exit hook of its own" do
      hooks = capture_at_exit_hooks(described_class)

      described_class.current

      expect(hooks).to be_empty
    end

    context "when the process forks after a failure was reported" do
      it "warns again in the child, which hasn't reported one", :aggregate_failures do
        expect { described_class.current.report(sink: "sink.jsonl", error: no_space, seq: 3) }
          .to output.to_stderr

        # An expectation inside the child can't report back to the parent, so
        # the child captures $stderr itself and returns what it got.
        warned_in_child = in_forked_child do
          captured = StringIO.new
          $stderr = captured # rubocop:disable RSpec/ExpectOutput
          described_class.current.report(sink: "sink.jsonl", error: no_space, seq: 3)
          captured.string
        end

        expect(warned_in_child).to start_with("lba: couldn't write a record")
      end
    end
  end
end
