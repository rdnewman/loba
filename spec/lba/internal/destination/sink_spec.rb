require "fileutils"
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

        described_class.for(io).append("record\n")

        expect(io.string).to eq("record\n")
        expect(Dir.empty?(tmp_dir)).to be true
      end
    end

    context "when given a path" do
      it "writes to it, creating its directory" do
        path = File.join(tmp_dir, "explicit", "records.jsonl")

        described_class.for(path).append("record\n")

        expect(File.read(path)).to eq("record\n")
      end

      it "writes to a Pathname's path" do
        path = File.join(tmp_dir, "explicit", "records.jsonl")

        described_class.for(Pathname(path)).append("record\n")

        expect(File.read(path)).to eq("record\n")
      end

      it "prefers it over LBA_SINK", :aggregate_failures do
        ENV["LBA_SINK"] = File.join(tmp_dir, "env", "records.jsonl")
        path = File.join(tmp_dir, "explicit", "records.jsonl")

        described_class.for(path).append("record\n")

        expect(File.read(path)).to eq("record\n")
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

        described_class.for(nil).append("record\n")

        expect(File.read(ENV.fetch("LBA_SINK"))).to eq("record\n")
      end

      it "ignores an empty LBA_SINK" do
        ENV["LBA_SINK"] = ""
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        described_class.for(nil).append("record\n")

        expect(File.read(run_file(".lba", "runs"))).to eq("record\n")
      end

      it "writes to the run's file under tmp/lba/runs in Rails.root, within Rails" do
        stub_const("Rails", double(root: tmp_dir))

        described_class.for(nil).append("record\n")

        expect(File.read(run_file("tmp", "lba", "runs"))).to eq("record\n")
      end

      it "writes under the working directory when Rails has no root (no app booted)" do
        stub_const("Rails", double(root: nil))
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        described_class.for(nil).append("record\n")

        expect(File.read(run_file(".lba", "runs"))).to eq("record\n")
      end

      it "writes to the run's file under .lba/runs in the working directory, outside Rails" do
        hide_const("Rails")
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        described_class.for(nil).append("record\n")

        expect(File.read(run_file(".lba", "runs"))).to eq("record\n")
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

        expect { described_class.for(nil).append("record\n") }
          .to output("record\n").to_stdout
      end

      it "writes to $stdout when a symlink was planted at the run's file" do
        hide_const("Rails")
        real_run = Lba::Internal::Run.new
        allow(Lba::Internal::Run).to receive(:current).and_return(real_run)
        allow(Dir).to receive(:pwd).and_return(tmp_dir)
        runs_dir = File.join(tmp_dir, ".lba", "runs")
        FileUtils.mkdir_p(runs_dir)
        File.symlink(File.join(tmp_dir, "target"), File.join(runs_dir, "#{real_run.id}.jsonl"))

        expect { described_class.for(nil).append("record\n") }
          .to output("record\n").to_stdout
      end
    end

    context "when the chosen directory can't be used" do
      it "writes to $stdout when the directory can't be created" do
        allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES)

        expect { described_class.for(nil).append("record\n") }
          .to output("record\n").to_stdout
      end

      it "writes to $stdout when the directory exists but isn't writable" do
        allow(Dir).to receive(:pwd).and_return(tmp_dir)
        allow(File).to receive(:writable?).and_return(false)

        expect { described_class.for(nil).append("record\n") }
          .to output("record\n").to_stdout
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

  describe "#append" do
    it "writes the line as given" do
      io = StringIO.new

      described_class.new(io).append("{\"type\":\"val\"}\n")

      expect(io.string).to eq("{\"type\":\"val\"}\n")
    end

    it "flushes an IO after writing, so a follower sees the line immediately" do
      io = instance_double(IO, write: nil, flush: nil)

      described_class.new(io).append("record\n")

      expect(io).to have_received(:flush).once
    end

    it "appends to a path without truncating what's there" do
      path = File.join(tmp_dir, "records.jsonl")
      File.write(path, "first\n")

      described_class.new(path).append("second\n")

      expect(File.read(path)).to eq("first\nsecond\n")
    end

    it "appends through a symlink given as the path" do
      target = File.join(tmp_dir, "target.jsonl")
      path = File.join(tmp_dir, "records.jsonl")
      File.symlink(target, path)

      described_class.new(path).append("record\n")

      expect(File.read(target)).to eq("record\n")
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

        described_class.new(path).append("record\n")

        expect(File.stat(path).mode & 0o777).to eq(0o600)
      end

      it "leaves an existing file's mode alone" do
        path = File.join(tmp_dir, "records.jsonl")
        File.write(path, "")
        File.chmod(0o644, path)

        described_class.new(path).append("record\n")

        expect(File.stat(path).mode & 0o777).to eq(0o644)
      end
    end

    # Deciding what a failed append means is Run::Delivery's job.
    context "when the target can't be written" do
      it "raises for a read-only file, leaving it untouched", :aggregate_failures do
        path = File.join(tmp_dir, "read_only.jsonl")
        File.write(path, "")
        File.chmod(0o444, path)

        expect { described_class.new(path).append("record\n") }.to raise_error(Errno::EACCES)
        expect(File.read(path)).to be_empty
      end

      it "raises for a closed IO" do
        io = StringIO.new
        io.close

        expect { described_class.new(io).append("record\n") }.to raise_error(IOError)
      end
    end
  end

  # Each call builds its own Sink, so two built for the same target are the
  # same sink.
  describe "equality" do
    it "holds for two Sinks on the same path", :aggregate_failures do
      sink = described_class.new("a.jsonl")
      same = described_class.new(+"a.jsonl")

      expect(sink).to eq(same)
      expect(sink).to eql(same)
      expect(sink.hash).to eq(same.hash)
    end

    it "holds for two Sinks on the same IO" do
      io = StringIO.new
      sink = described_class.new(io)
      same = described_class.new(io)

      expect(sink).to eql(same)
    end

    it "fails for Sinks on different paths" do
      expect(described_class.new("a.jsonl")).not_to eql(described_class.new("b.jsonl"))
    end

    it "fails for Sinks on different IOs, even ones with the same contents" do
      expect(described_class.new(StringIO.new)).not_to eql(described_class.new(StringIO.new))
    end

    it "fails for the target itself" do
      expect(described_class.new("a.jsonl")).not_to eq("a.jsonl")
    end

    it "lets another Sink on the same target find a Hash entry" do
      entries = { described_class.new("a.jsonl") => :gap }

      expect(entries[described_class.new("a.jsonl")]).to eq(:gap)
    end
  end

  describe "#to_s" do
    it "names a path as inspect shows it, for lba's messages" do
      expect(described_class.new("a.jsonl").to_s).to eq("\"a.jsonl\"")
    end

    it "names an IO as inspect shows it" do
      io = StringIO.new

      expect(described_class.new(io).to_s).to eq(io.inspect)
    end
  end
end
