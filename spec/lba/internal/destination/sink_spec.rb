require "fileutils"
require "json"
require "pathname"
require "stringio"

RSpec.describe Lba::Internal::Destination::Sink do
  let(:tmp_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmp_dir) }

  describe ".for" do
    let(:run) do
      instance_double(Lba::Internal::Run, id: "20260830T143012Z-4242-ab12cd34", claim_file: true)
    end

    around do |example|
      original_lba_sink = ENV.delete("LBA_SINK")
      example.run
    ensure
      ENV["LBA_SINK"] = original_lba_sink if original_lba_sink
    end

    before { allow(Lba::Internal::Run).to receive(:current).and_return(run) }

    def run_file(*dirs) = File.join(tmp_dir, *dirs, "#{run.id}.jsonl")

    context "when given an IO" do
      it "writes to it, without touching the filesystem", :aggregate_failures do
        allow(Dir).to receive(:pwd).and_return(tmp_dir)
        io = StringIO.new

        described_class.for(io).write({ seq: 1 })

        expect(io.string).to eq("{\"seq\":1}\n")
        expect(Dir.empty?(tmp_dir)).to be true
      end
    end

    context "when given a path" do
      it "writes to it, creating its directory" do
        path = File.join(tmp_dir, "explicit", "records.jsonl")

        described_class.for(path).write({ seq: 1 })

        expect(File.read(path)).to eq("{\"seq\":1}\n")
      end

      it "writes to a Pathname's path" do
        path = File.join(tmp_dir, "explicit", "records.jsonl")

        described_class.for(Pathname(path)).write({ seq: 1 })

        expect(File.read(path)).to eq("{\"seq\":1}\n")
      end

      it "prefers it over LBA_SINK", :aggregate_failures do
        ENV["LBA_SINK"] = File.join(tmp_dir, "env", "records.jsonl")
        path = File.join(tmp_dir, "explicit", "records.jsonl")

        described_class.for(path).write({ seq: 1 })

        expect(File.read(path)).to eq("{\"seq\":1}\n")
        expect(File.exist?(ENV.fetch("LBA_SINK"))).to be false
      end

      it "doesn't ask the run to claim it, since only the run's own file is claimed" do
        described_class.for(File.join(tmp_dir, "explicit", "records.jsonl"))

        expect(run).not_to have_received(:claim_file)
      end
    end

    context "when given no sink" do
      it "writes to LBA_SINK's path, creating its directory" do
        ENV["LBA_SINK"] = File.join(tmp_dir, "env", "records.jsonl")

        described_class.for(nil).write({ seq: 1 })

        expect(File.read(ENV.fetch("LBA_SINK"))).to eq("{\"seq\":1}\n")
      end

      it "ignores an empty LBA_SINK" do
        ENV["LBA_SINK"] = ""
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        described_class.for(nil).write({ seq: 1 })

        expect(File.read(run_file(".lba", "runs"))).to eq("{\"seq\":1}\n")
      end

      it "writes to the run's file under tmp/lba/runs in Rails.root, within Rails" do
        stub_const("Rails", double(root: tmp_dir))

        described_class.for(nil).write({ seq: 1 })

        expect(File.read(run_file("tmp", "lba", "runs"))).to eq("{\"seq\":1}\n")
      end

      it "writes under the working directory when Rails has no root (no app booted)" do
        stub_const("Rails", double(root: nil))
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        described_class.for(nil).write({ seq: 1 })

        expect(File.read(run_file(".lba", "runs"))).to eq("{\"seq\":1}\n")
      end

      it "writes to the run's file under .lba/runs in the working directory, outside Rails" do
        hide_const("Rails")
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        described_class.for(nil).write({ seq: 1 })

        expect(File.read(run_file(".lba", "runs"))).to eq("{\"seq\":1}\n")
      end

      it "has the run claim its own file before using it" do
        hide_const("Rails")
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        described_class.for(nil)

        expect(run).to have_received(:claim_file).with(run_file(".lba", "runs"))
      end

      it "writes to $stdout when the run can't claim its file" do
        hide_const("Rails")
        allow(Dir).to receive(:pwd).and_return(tmp_dir)
        allow(run).to receive(:claim_file).and_return(false)

        expect { described_class.for(nil).write({ seq: 1 }) }
          .to output("{\"seq\":1}\n").to_stdout
      end

      it "writes to $stdout when a symlink was planted at the run's file" do
        hide_const("Rails")
        real_run = Lba::Internal::Run.new
        allow(Lba::Internal::Run).to receive(:current).and_return(real_run)
        allow(Dir).to receive(:pwd).and_return(tmp_dir)
        runs_dir = File.join(tmp_dir, ".lba", "runs")
        FileUtils.mkdir_p(runs_dir)
        File.symlink(File.join(tmp_dir, "target"), File.join(runs_dir, "#{real_run.id}.jsonl"))

        expect { described_class.for(nil).write({ seq: 1 }) }
          .to output("{\"seq\":1}\n").to_stdout
      end
    end

    context "when the chosen directory can't be used" do
      it "writes to $stdout when the directory can't be created" do
        allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES)

        expect { described_class.for(nil).write({ seq: 1 }) }
          .to output("{\"seq\":1}\n").to_stdout
      end

      it "writes to $stdout when the directory exists but isn't writable" do
        allow(Dir).to receive(:pwd).and_return(tmp_dir)
        allow(File).to receive(:writable?).and_return(false)

        expect { described_class.for(nil).write({ seq: 1 }) }
          .to output("{\"seq\":1}\n").to_stdout
      end
    end

    context "with the common umask of 022" do
      around do |example|
        original_umask = File.umask(0o022)
        example.run
      ensure
        File.umask(original_umask)
      end

      it "creates the run's directories accessible only by their owner" do
        hide_const("Rails")
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        described_class.for(nil)

        modes = [".lba", ".lba/runs"].map { |dir| File.stat(File.join(tmp_dir, dir)).mode & 0o777 }
        expect(modes).to eq([0o700, 0o700])
      end

      it "creates a given path's directory with the usual mode" do
        path = File.join(tmp_dir, "explicit", "records.jsonl")

        described_class.for(path)

        expect(File.stat(File.dirname(path)).mode & 0o777).to eq(0o755)
      end
    end
  end

  describe "#write" do
    it "appends the record as one JSON line, with a trailing newline" do
      io = StringIO.new

      described_class.new(io).write({ "type" => "val", "label" => "foo" })

      expect(io.string).to eq("{\"type\":\"val\",\"label\":\"foo\"}\n")
    end

    it "flushes an IO after writing, so a follower sees the record immediately" do
      io = instance_double(IO, write: nil, flush: nil)

      described_class.new(io).write({ "type" => "ts" })

      expect(io).to have_received(:flush).once
    end

    it "appends to a path without truncating what's there" do
      path = File.join(tmp_dir, "records.jsonl")
      File.write(path, "{\"seq\":1}\n")

      described_class.new(path).write({ "seq" => 2 })

      expect(File.read(path)).to eq("{\"seq\":1}\n{\"seq\":2}\n")
    end

    it "appends through a symlink given as the path" do
      target = File.join(tmp_dir, "target.jsonl")
      path = File.join(tmp_dir, "records.jsonl")
      File.symlink(target, path)

      described_class.new(path).write({ "seq" => 1 })

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
      it "creates a new file readable and writable only by its owner" do
        path = File.join(tmp_dir, "records.jsonl")

        described_class.new(path).write({ "seq" => 1 })

        expect(File.stat(path).mode & 0o777).to eq(0o600)
      end

      it "leaves an existing file's mode alone" do
        path = File.join(tmp_dir, "records.jsonl")
        File.write(path, "")
        File.chmod(0o644, path)

        described_class.new(path).write({ "seq" => 1 })

        expect(File.stat(path).mode & 0o777).to eq(0o644)
      end
    end

    # A full disk or an unwritable sink is the environment's problem, not the
    # traced code's, so it never raises into it.
    context "when the sink can't be written" do
      after { reset_current(Lba::Internal::Run::WriteFailures) }

      it "skips a read-only file and warns, without raising", :aggregate_failures do
        path = File.join(tmp_dir, "read_only.jsonl")
        File.write(path, "")
        File.chmod(0o444, path)

        expect { described_class.new(path).write({ "seq" => 1 }) }
          .to output(/lba: couldn't write a record to "#{Regexp.escape(path)}" .*Errno::EACCES/)
          .to_stderr
        expect(File.read(path)).to be_empty
      end

      it "skips a closed IO and warns, without raising" do
        io = StringIO.new
        io.close

        expect { described_class.new(io).write({ "seq" => 1 }) }
          .to output(/lba: couldn't write a record .*IOError/).to_stderr
      end
    end

    # So a record that was dropped isn't mistaken for code that never ran.
    context "when earlier records to the sink couldn't be written" do
      before { allow(Lba::Internal::Run::WriteFailures.current).to receive(:warn) }

      after { reset_current(Lba::Internal::Run::WriteFailures) }

      # Fails its first few writes with a full disk, then succeeds.
      def flaky_io(failures)
        io = StringIO.new
        allow(io).to receive(:write).and_wrap_original do |original, line|
          raise Errno::ENOSPC if (failures -= 1) >= 0

          original.call(line)
        end
        io
      end

      def written_lines(io) = io.string.lines.map { JSON.parse(_1) }

      it "notes them on the next record written there" do
        io = flaky_io(2)
        sink = described_class.new(io)

        [3, 4, 5].each { |seq| sink.write({ seq: }) }

        expect(written_lines(io)).to eq(
          [{ "seq" => 5, "unwritten" => {
            "count" => 2, "first_seq" => 3, "last_seq" => 4,
            "error" => "Errno::ENOSPC: No space left on device"
          } }]
        )
      end

      it "notes them on the next record from another Sink to the same target" do
        io = flaky_io(1)
        described_class.new(io).write({ seq: 3 })

        described_class.new(io).write({ seq: 4 })

        expect(written_lines(io).last).to include("unwritten" => include("count" => 1))
      end

      # A gap qualifies the record's place in the run, so it comes right after
      # the record's seq and type, before anything that could make a line long.
      it "notes them right after the record's seq and type" do
        io = flaky_io(1)
        sink = described_class.new(io)

        [3, 4].each { |seq| sink.write({ seq:, type: "ts", label: "after" }) }

        expect(written_lines(io).last.keys).to eq(["seq", "type", "unwritten", "label"])
      end

      it "notes them only once" do
        io = flaky_io(1)
        sink = described_class.new(io)

        [3, 4, 5].each { |seq| sink.write({ seq: }) }

        expect(written_lines(io).last).to eq("seq" => 5)
      end

      it "notes them only on the sink that missed them" do
        other = StringIO.new
        described_class.new(flaky_io(1)).write({ seq: 3 })

        described_class.new(other).write({ seq: 4 })

        expect(written_lines(other)).to eq([{ "seq" => 4 }])
      end
    end

    it "leaves the failure tracking alone when writes succeed" do
      described_class.new(StringIO.new).write({ seq: 1 })

      expect(Lba::Internal::Run::WriteFailures.existing).to be_nil
    end

    context "when writing fails for any other reason" do
      it "raises, since that's a bug in lba" do
        io = instance_double(IO)
        allow(io).to receive(:write).and_raise(RuntimeError, "lba bug")

        expect { described_class.new(io).write({ "seq" => 1 }) }
          .to raise_error(RuntimeError, "lba bug")
      end
    end
  end
end
