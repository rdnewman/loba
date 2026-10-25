require "fileutils"
require "pathname"
require "stringio"

RSpec.describe Loba::Internal::Destination::Sink do
  let(:tmp_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmp_dir) }

  describe ".for" do
    let(:run) do
      instance_double(Loba::Internal::Run, id: "20260830T143012Z-4242-ab12cd34", claim_file: true,
                                           report_fallback: nil)
    end

    around do |example|
      original_loba_sink = ENV.delete("LOBA_SINK")
      example.run
    ensure
      ENV["LOBA_SINK"] = original_loba_sink if original_loba_sink
    end

    before do
      allow(Loba::Internal::Run).to receive(:current).and_return(run)
      allow(run).to receive(:start_dir).and_return(tmp_dir)
    end

    def run_file(*dirs) = File.join(tmp_dir, *dirs, "#{run.id}.jsonl")

    # A directory other than the run's start directory, to chdir into.
    def elsewhere_dir
      File.join(tmp_dir, "elsewhere").tap { |dir| FileUtils.mkdir_p(dir) }
    end

    context "when given an IO" do
      it "writes to it, without touching the filesystem", :aggregate_failures do
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

      it "prefers it over LOBA_SINK", :aggregate_failures do
        ENV["LOBA_SINK"] = File.join(tmp_dir, "env", "records.jsonl")
        path = File.join(tmp_dir, "explicit", "records.jsonl")

        described_class.for(path).append("record\n")

        expect(File.read(path)).to eq("record\n")
        expect(File.exist?(ENV.fetch("LOBA_SINK"))).to be false
      end

      it "doesn't ask the run to claim it, since only the run's own file is claimed" do
        described_class.for(File.join(tmp_dir, "explicit", "records.jsonl"))

        expect(run).not_to have_received(:claim_file)
      end

      # A relative path names a different file after a chdir, and two names
      # for one file would keep two separate gaps.
      it "takes a relative path from the directory the run started in, not the current one" do
        sink = Dir.chdir(elsewhere_dir) { described_class.for("records.jsonl") }

        expect(sink).to eq(described_class.new(File.join(tmp_dir, "records.jsonl")))
      end

      # As File.open does; expanding it would raise for a user that doesn't
      # exist.
      it "takes a leading ~ as part of a relative path, not a home directory" do
        sink = described_class.for("~nosuchuser/records.jsonl")

        expected_path = File.join(tmp_dir, "~nosuchuser", "records.jsonl")
        expect(sink).to eq(described_class.new(expected_path))
      end

      it "keeps its own copy of the path, unaffected by later changes to the String" do
        path = File.join(tmp_dir, "records.jsonl")
        given = path.dup
        sink = described_class.for(given)

        given.replace(File.join(tmp_dir, "other.jsonl"))

        expect(sink).to eq(described_class.new(path))
      end
    end

    context "when given no sink" do
      it "writes to LOBA_SINK's path, creating its directory" do
        ENV["LOBA_SINK"] = File.join(tmp_dir, "env", "records.jsonl")

        described_class.for(nil).append("record\n")

        expect(File.read(ENV.fetch("LOBA_SINK"))).to eq("record\n")
      end

      it "takes a relative LOBA_SINK from the directory the run started in, not the current one" do
        ENV["LOBA_SINK"] = "records.jsonl"

        sink = Dir.chdir(elsewhere_dir) { described_class.for(nil) }

        expect(sink).to eq(described_class.new(File.join(tmp_dir, "records.jsonl")))
      end

      it "writes the run's file under the directory the run started in, after a chdir" do
        hide_const("Rails")

        Dir.chdir(elsewhere_dir) { described_class.for(nil).append("record\n") }

        expect(File.read(run_file(".loba", "runs"))).to eq("record\n")
      end

      it "ignores an empty LOBA_SINK" do
        ENV["LOBA_SINK"] = ""

        described_class.for(nil).append("record\n")

        expect(File.read(run_file(".loba", "runs"))).to eq("record\n")
      end

      it "writes to the run's file under tmp/loba/runs in Rails.root, within Rails" do
        stub_const("Rails", double(root: tmp_dir))

        described_class.for(nil).append("record\n")

        expect(File.read(run_file("tmp", "loba", "runs"))).to eq("record\n")
      end

      it "writes under the working directory when Rails has no root (no app booted)" do
        stub_const("Rails", double(root: nil))

        described_class.for(nil).append("record\n")

        expect(File.read(run_file(".loba", "runs"))).to eq("record\n")
      end

      it "writes to the run's file under .loba/runs in the working directory, outside Rails" do
        hide_const("Rails")

        described_class.for(nil).append("record\n")

        expect(File.read(run_file(".loba", "runs"))).to eq("record\n")
      end

      it "has the run claim its own file before using it" do
        hide_const("Rails")

        described_class.for(nil)

        expect(run).to have_received(:claim_file).with(run_file(".loba", "runs"))
      end

      it "writes to $stdout when the run can't claim its file" do
        hide_const("Rails")
        allow(run).to receive(:claim_file).and_return(false)

        expect { described_class.for(nil).append("record\n") }
          .to output("record\n").to_stdout
      end

      it "writes to $stdout when a symlink was planted at the run's file" do
        hide_const("Rails")
        real_run = Dir.chdir(tmp_dir) { Loba::Internal::Run.new }
        allow(real_run).to receive(:warn)
        allow(Loba::Internal::Run).to receive(:current).and_return(real_run)
        runs_dir = File.join(tmp_dir, ".loba", "runs")
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
        allow(File).to receive(:writable?).and_return(false)

        expect { described_class.for(nil).append("record\n") }
          .to output("record\n").to_stdout
      end
    end

    context "when falling back to $stdout" do
      it "reports a given path whose directory can't be created, with the error" do
        path = File.join(tmp_dir, "explicit", "records.jsonl")
        allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES)

        described_class.for(path)

        expect(run).to have_received(:report_fallback)
          .with(path:, reason: "Errno::EACCES: Permission denied")
      end

      it "reports a directory that isn't writable" do
        hide_const("Rails")
        allow(File).to receive(:writable?).and_return(false)

        described_class.for(nil)

        expect(run).to have_received(:report_fallback)
          .with(path: run_file(".loba", "runs"), reason: "its directory isn't writable")
      end

      it "reports the run's file when the run can't claim it" do
        hide_const("Rails")
        allow(run).to receive(:claim_file).and_return(false)

        described_class.for(nil)

        expect(run).to have_received(:report_fallback)
          .with(path: run_file(".loba", "runs"),
                reason: "this run couldn't create it as a new file")
      end

      it "reports nothing when the path can be used" do
        described_class.for(File.join(tmp_dir, "explicit", "records.jsonl"))

        expect(run).not_to have_received(:report_fallback)
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

        described_class.for(nil)

        modes = [".loba", ".loba/runs"].map do |dir|
          File.stat(File.join(tmp_dir, dir)).mode & 0o777
        end
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

    # Deciding what a failed append means is Run::Recorder's job.
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
    it "names a path as inspect shows it, for loba's messages" do
      expect(described_class.new("a.jsonl").to_s).to eq("\"a.jsonl\"")
    end

    it "names an IO as inspect shows it" do
      io = StringIO.new

      expect(described_class.new(io).to_s).to eq(io.inspect)
    end
  end
end
