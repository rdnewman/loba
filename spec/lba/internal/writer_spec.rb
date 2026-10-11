require "fileutils"
require "stringio"

RSpec.describe Lba::Internal::Writer do
  let(:tmp_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmp_dir) }

  describe ".write" do
    it "appends the record as one JSON line, adding a trailing newline" do
      sink = StringIO.new

      described_class.write({ "type" => "val", "label" => "foo" }, sink:)

      expect(sink.string).to eq("{\"type\":\"val\",\"label\":\"foo\"}\n")
    end

    it "flushes an IO sink after writing so a follower sees the record immediately" do
      sink = instance_double(IO, write: nil, flush: nil)

      described_class.write({ "type" => "ts" }, sink:)

      expect(sink).to have_received(:flush).once
    end

    it "appends to a path sink without truncating existing content" do
      path = File.join(tmp_dir, "sink.jsonl")
      File.write(path, "{\"seq\":1}\n")

      described_class.write({ "seq" => 2 }, sink: path)

      expect(File.read(path)).to eq("{\"seq\":1}\n{\"seq\":2}\n")
    end

    it "appends through a symlink given as the sink" do
      target = File.join(tmp_dir, "target.jsonl")
      path = File.join(tmp_dir, "sink.jsonl")
      File.symlink(target, path)

      described_class.write({ "seq" => 1 }, sink: path)

      expect(File.read(target)).to eq("{\"seq\":1}\n")
    end

    context "with the common umask of 022" do
      around do |example|
        original_umask = File.umask(0o022)
        example.run
      ensure
        File.umask(original_umask)
      end

      # Records hold unredacted values, so other local users shouldn't read them.
      it "creates a new path sink readable and writable only by its owner" do
        path = File.join(tmp_dir, "sink.jsonl")

        described_class.write({ "seq" => 1 }, sink: path)

        expect(File.stat(path).mode & 0o777).to eq(0o600)
      end

      it "leaves an existing path sink's mode alone" do
        path = File.join(tmp_dir, "sink.jsonl")
        File.write(path, "")
        File.chmod(0o644, path)

        described_class.write({ "seq" => 1 }, sink: path)

        expect(File.stat(path).mode & 0o777).to eq(0o644)
      end
    end

    # A full disk or an unwritable sink is the environment's problem, not the
    # traced code's, so it never raises into it.
    context "when the sink can't be written" do
      before { capture_at_exit_hooks(Lba::Internal::WriteFailures) }

      after { reset_current(Lba::Internal::WriteFailures) }

      it "skips a read-only file and warns, without raising", :aggregate_failures do
        path = File.join(tmp_dir, "read_only.jsonl")
        File.write(path, "")
        File.chmod(0o444, path)

        expect { described_class.write({ "seq" => 1 }, sink: path) }
          .to output(/lba: couldn't write a record .*Errno::EACCES/).to_stderr
        expect(File.read(path)).to be_empty
      end

      it "skips a closed IO and warns, without raising" do
        sink = StringIO.new
        sink.close

        expect { described_class.write({ "seq" => 1 }, sink:) }
          .to output(/lba: couldn't write a record .*IOError/).to_stderr
      end
    end

    # So a record that was dropped isn't mistaken for code that never ran.
    context "when earlier records to the sink couldn't be written" do
      before do
        capture_at_exit_hooks(Lba::Internal::WriteFailures)
        allow(Lba::Internal::WriteFailures.current).to receive(:warn)
      end

      after { reset_current(Lba::Internal::WriteFailures) }

      # Fails its first few writes with a full disk, then succeeds.
      def flaky_sink(failures)
        sink = StringIO.new
        allow(sink).to receive(:write).and_wrap_original do |original, line|
          raise Errno::ENOSPC if (failures -= 1) >= 0

          original.call(line)
        end
        sink
      end

      def written_lines(sink) = sink.string.lines.map { JSON.parse(_1) }

      it "notes them on the next record written there" do
        sink = flaky_sink(2)

        [3, 4, 5].each { |seq| described_class.write({ seq: }, sink:) }

        expect(written_lines(sink)).to eq(
          [{ "seq" => 5, "unwritten" => {
            "count" => 2, "first_seq" => 3, "last_seq" => 4,
            "error" => "Errno::ENOSPC: No space left on device"
          } }]
        )
      end

      it "notes them only once" do
        sink = flaky_sink(1)

        [3, 4, 5].each { |seq| described_class.write({ seq: }, sink:) }

        expect(written_lines(sink).last).to eq("seq" => 5)
      end

      it "notes them only on the sink that missed them" do
        flaky = flaky_sink(1)
        other = StringIO.new
        described_class.write({ seq: 3 }, sink: flaky)

        described_class.write({ seq: 4 }, sink: other)

        expect(written_lines(other)).to eq([{ "seq" => 4 }])
      end
    end

    it "leaves the failure tracking alone when writes succeed" do
      described_class.write({ seq: 1 }, sink: StringIO.new)

      expect(Lba::Internal::WriteFailures.existing).to be_nil
    end

    context "when writing fails for any other reason" do
      it "raises, since that's a bug in lba" do
        sink = instance_double(IO)
        allow(sink).to receive(:write).and_raise(RuntimeError, "lba bug")

        expect { described_class.write({ "seq" => 1 }, sink:) }
          .to raise_error(RuntimeError, "lba bug")
      end
    end
  end
end
