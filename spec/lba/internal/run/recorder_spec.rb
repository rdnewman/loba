require "json"
require "stringio"

RSpec.describe Lba::Internal::Run::Recorder do
  def sink_to(target) = Lba::Internal::Destination::Sink.new(target)

  # A sink on the path whose every append fails.
  def failing_sink(path, error: Errno::ENOSPC.new)
    sink_to(path).tap { |sink| allow(sink).to receive(:append).and_raise(error) }
  end

  # An IO that raises each of the errors on one write, in order, then writes
  # normally.
  def flaky_io(*errors)
    io = StringIO.new
    allow(io).to receive(:write).and_wrap_original do |original, line|
      error = errors.shift
      raise error if error

      original.call(line)
    end
    io
  end

  def written_lines(io) = io.string.lines.map { JSON.parse(_1) }

  # For examples about something other than the warning.
  def quiet_recorder
    described_class.new.tap { |recorder| allow(recorder).to receive(:warn) }
  end

  describe "#write" do
    it "appends the record to the sink as one JSON line" do
      io = StringIO.new

      described_class.new.write({ seq: 1, type: "ts" }, to: sink_to(io))

      expect(io.string).to eq("{\"seq\":1,\"type\":\"ts\"}\n")
    end

    # A full disk or an unwritable sink is the environment's problem, not the
    # traced code's, so it never raises into it.
    context "when the sink can't be written" do
      it "warns on $stderr about the first failure, naming the sink and the error" do
        sink = failing_sink("sink.jsonl", error: Errno::EACCES.new("sink.jsonl"))

        expect { described_class.new.write({ seq: 3 }, to: sink) }.to output(
          "lba: couldn't write a record to \"sink.jsonl\" " \
          "(Errno::EACCES: Permission denied - sink.jsonl); " \
          "later write failures in this process won't be reported\n"
        ).to_stderr
      end

      it "stays quiet about later failures, to any sink", :aggregate_failures do
        recorder = described_class.new
        expect { recorder.write({ seq: 3 }, to: failing_sink("a.jsonl")) }.to output.to_stderr

        expect { recorder.write({ seq: 4 }, to: failing_sink("b.jsonl")) }
          .not_to output.to_stderr
      end

      it "skips a read-only file, without raising", :aggregate_failures do
        Dir.mktmpdir do |dir|
          path = File.join(dir, "read_only.jsonl")
          File.write(path, "")
          File.chmod(0o444, path)

          expect { described_class.new.write({ seq: 1 }, to: sink_to(path)) }
            .to output(/Errno::EACCES/).to_stderr
          expect(File.read(path)).to be_empty
        end
      end

      it "skips a closed IO, without raising" do
        io = StringIO.new
        io.close

        expect { described_class.new.write({ seq: 1 }, to: sink_to(io)) }
          .to output(/IOError/).to_stderr
      end
    end

    # So a record that was dropped isn't mistaken for code that never ran.
    context "when earlier records to the sink couldn't be written" do
      it "notes them on the next record written there" do
        io = flaky_io(Errno::ENOSPC, Errno::ENOSPC)
        recorder = quiet_recorder
        sink = sink_to(io)

        [3, 4, 5].each { |seq| recorder.write({ seq: }, to: sink) }

        expect(written_lines(io)).to eq(
          [{ "seq" => 5, "unwritten" => {
            "count" => 2, "first_seq" => 3, "last_seq" => 4,
            "error" => "Errno::ENOSPC: No space left on device"
          } }]
        )
      end

      it "notes the first error for them all" do
        io = flaky_io(Errno::ENOSPC, Errno::EACCES)
        recorder = quiet_recorder
        sink = sink_to(io)

        [3, 4, 5].each { |seq| recorder.write({ seq: }, to: sink) }

        expect(written_lines(io).last["unwritten"])
          .to include("count" => 2, "error" => "Errno::ENOSPC: No space left on device")
      end

      it "notes them on the next record from another Sink to the same target" do
        io = flaky_io(Errno::ENOSPC)
        recorder = quiet_recorder
        recorder.write({ seq: 3 }, to: sink_to(io))

        recorder.write({ seq: 4 }, to: sink_to(io))

        expect(written_lines(io).last).to include("unwritten" => include("count" => 1))
      end

      # A gap qualifies the record's place in the run, so it comes right after
      # the record's seq and type, before anything that could make a line long.
      it "notes them right after the record's seq and type" do
        io = flaky_io(Errno::ENOSPC)
        recorder = quiet_recorder
        sink = sink_to(io)

        [3, 4].each { |seq| recorder.write({ seq:, type: "ts", label: "after" }, to: sink) }

        expect(written_lines(io).last.keys).to eq(["seq", "type", "unwritten", "label"])
      end

      it "notes them only once" do
        io = flaky_io(Errno::ENOSPC)
        recorder = quiet_recorder
        sink = sink_to(io)

        [3, 4, 5].each { |seq| recorder.write({ seq: }, to: sink) }

        expect(written_lines(io).last).to eq("seq" => 5)
      end

      it "notes them only on the sink that missed them" do
        other = StringIO.new
        recorder = quiet_recorder
        recorder.write({ seq: 3 }, to: sink_to(flaky_io(Errno::ENOSPC)))

        recorder.write({ seq: 4 }, to: sink_to(other))

        expect(written_lines(other)).to eq([{ "seq" => 4 }])
      end

      it "notes them on only one record when threads write there at once" do
        io = StringIO.new
        failures = [Errno::ENOSPC]
        # Fails once, then holds each write long enough for another thread to
        # find the same gap.
        allow(io).to receive(:write).and_wrap_original do |original, line|
          raise failures.shift unless failures.empty?

          sleep 0.05
          original.call(line)
        end
        recorder = quiet_recorder
        sink = sink_to(io)
        recorder.write({ seq: 3 }, to: sink)

        [4, 5].map { |seq| Thread.new { recorder.write({ seq: }, to: sink) } }.each(&:join)

        expect(written_lines(io).count { _1.has_key?("unwritten") }).to eq(1)
      end

      # An error that isn't a write failure (a Timeout, say) can interrupt the
      # write that would have noted them.
      it "keeps them for the next record when that write raises", :aggregate_failures do
        io = flaky_io(Errno::ENOSPC, RuntimeError.new("interrupted"))
        recorder = quiet_recorder
        sink = sink_to(io)
        recorder.write({ seq: 3 }, to: sink)
        expect { recorder.write({ seq: 4 }, to: sink) }.to raise_error(RuntimeError)

        recorder.write({ seq: 5 }, to: sink)

        expect(written_lines(io).last["unwritten"]).to include("count" => 1, "last_seq" => 3)
      end
    end

    context "when writing fails for any other reason" do
      it "raises, since that's a bug in lba" do
        sink = failing_sink("a.jsonl", error: RuntimeError.new("lba bug"))

        expect { described_class.new.write({ seq: 1 }, to: sink) }
          .to raise_error(RuntimeError, "lba bug")
      end
    end
  end

  describe "#summarize" do
    it "warns on $stderr about each sink's records never noted there, one line per sink" do
      recorder = quiet_recorder
      recorder.write({ seq: 3 }, to: failing_sink("a.jsonl"))
      recorder.write({ seq: 4 }, to: failing_sink("a.jsonl"))
      recorder.write({ seq: 5 }, to: failing_sink("b.jsonl", error: Errno::EACCES.new))
      allow(recorder).to receive(:warn).and_call_original

      expect { recorder.summarize }.to output(
        "lba: 2 records couldn't be written to \"a.jsonl\" " \
        "(first error: Errno::ENOSPC: No space left on device)\n" \
        "lba: 1 record couldn't be written to \"b.jsonl\" " \
        "(first error: Errno::EACCES: Permission denied)\n"
      ).to_stderr
    end

    it "lets another thread miss a record while it warns", :aggregate_failures do
      recorder = quiet_recorder
      recorder.write({ seq: 3 }, to: failing_sink("a.jsonl"))
      warning = Queue.new
      # Holds the summary partway through its warnings.
      allow(recorder).to receive(:warn) do
        warning << true
        sleep 0.05
      end
      summarizer = Thread.new { recorder.summarize }
      held = warning.pop(timeout: 5)

      writer = Thread.new { recorder.write({ seq: 4 }, to: failing_sink("b.jsonl")) }

      expect(held).to be true
      expect { [summarizer, writer].each(&:join) }.not_to raise_error
    end

    it "warns about nothing for a sink whose gap was since noted" do
      io = flaky_io(Errno::ENOSPC)
      recorder = quiet_recorder
      [3, 4].each { |seq| recorder.write({ seq: }, to: sink_to(io)) }
      allow(recorder).to receive(:warn).and_call_original

      expect { recorder.summarize }.not_to output.to_stderr
    end
  end
end
