require "fileutils"
require "pathname"
require "stringio"

RSpec.describe Lba::Internal::SinkResolver, :aggregate_failures do
  let(:run) do
    instance_double(Lba::Internal::Run, id: "20260830T143012Z-4242-ab12cd34", claim_file: true)
  end
  let(:tmp_dir) { Dir.mktmpdir }

  around do |example|
    original_lba_sink = ENV.delete("LBA_SINK")
    example.run
  ensure
    ENV["LBA_SINK"] = original_lba_sink if original_lba_sink
  end

  after { FileUtils.remove_entry(tmp_dir) }

  describe ".resolve" do
    it "returns an explicit sink IO unchanged, without touching the filesystem" do
      sink = StringIO.new

      expect(described_class.resolve(sink:, run:)).to equal(sink)
    end

    it "creates the parent directory for an explicit sink path and returns it" do
      path = File.join(tmp_dir, "explicit", "sink.jsonl")

      resolved = described_class.resolve(sink: path, run:)

      expect(resolved).to eq(path)
      expect(Dir.exist?(File.dirname(path))).to be true
    end

    it "returns a Pathname sink as its path, so it's appended to like any path" do
      path = File.join(tmp_dir, "explicit", "sink.jsonl")

      resolved = described_class.resolve(sink: Pathname(path), run:)

      expect(resolved).to eq(path)
    end

    it "prefers the explicit sink kwarg over LBA_SINK" do
      ENV["LBA_SINK"] = File.join(tmp_dir, "env", "sink.jsonl")
      path = File.join(tmp_dir, "explicit", "sink.jsonl")

      expect(described_class.resolve(sink: path, run:)).to eq(path)
    end

    it "uses LBA_SINK when no explicit sink is given" do
      env_path = File.join(tmp_dir, "env", "sink.jsonl")
      ENV["LBA_SINK"] = env_path

      resolved = described_class.resolve(run:)

      expect(resolved).to eq(env_path)
      expect(Dir.exist?(File.dirname(env_path))).to be true
    end

    it "ignores an empty LBA_SINK" do
      ENV["LBA_SINK"] = ""
      allow(Dir).to receive(:pwd).and_return(tmp_dir)

      resolved = described_class.resolve(run:)

      expect(resolved).to eq(File.join(tmp_dir, ".lba", "runs", "#{run.id}.jsonl"))
    end

    it "defaults to tmp/lba/runs/<run_id>.jsonl under Rails.root when within Rails" do
      stub_const("Rails", double(root: tmp_dir))

      resolved = described_class.resolve(run:)

      expect(resolved).to eq(File.join(tmp_dir, "tmp", "lba", "runs", "#{run.id}.jsonl"))
      expect(Dir.exist?(File.dirname(resolved))).to be true
    end

    it "defaults to the working directory when Rails has no root (no app booted)" do
      stub_const("Rails", double(root: nil))
      allow(Dir).to receive(:pwd).and_return(tmp_dir)

      resolved = described_class.resolve(run:)

      expect(resolved).to eq(File.join(tmp_dir, ".lba", "runs", "#{run.id}.jsonl"))
    end

    it "defaults to .lba/runs/<run_id>.jsonl under the working directory outside Rails" do
      allow(Dir).to receive(:pwd).and_return(tmp_dir)

      resolved = described_class.resolve(run:)

      expect(resolved).to eq(File.join(tmp_dir, ".lba", "runs", "#{run.id}.jsonl"))
      expect(Dir.exist?(File.dirname(resolved))).to be true
    end

    it "falls back to $stdout when the resolved directory can't be created" do
      allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES)

      expect(described_class.resolve(run:)).to equal($stdout)
    end

    it "falls back to $stdout when the resolved directory exists but isn't writable" do
      allow(Dir).to receive(:pwd).and_return(tmp_dir)
      allow(File).to receive(:writable?).and_return(false)

      expect(described_class.resolve(run:)).to equal($stdout)
    end

    describe "the run's own file" do
      it "is claimed by the run before it's used" do
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        resolved = described_class.resolve(run:)

        expect(run).to have_received(:claim_file).with(resolved)
      end

      it "falls back to $stdout when the run can't claim it" do
        allow(Dir).to receive(:pwd).and_return(tmp_dir)
        allow(run).to receive(:claim_file).and_return(false)

        expect(described_class.resolve(run:)).to equal($stdout)
      end

      it "falls back to $stdout when a symlink was planted at its path" do
        run = Lba::Internal::Run.new
        runs_dir = File.join(tmp_dir, ".lba", "runs")
        FileUtils.mkdir_p(runs_dir)
        File.symlink(File.join(tmp_dir, "target"), File.join(runs_dir, "#{run.id}.jsonl"))
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        expect(described_class.resolve(run:)).to equal($stdout)
      end
    end

    it "leaves claiming to the run only for its own file, not a path it was given" do
      path = File.join(tmp_dir, "explicit", "sink.jsonl")

      described_class.resolve(sink: path, run:)

      expect(run).not_to have_received(:claim_file)
    end

    context "with the common umask of 022" do
      around do |example|
        original_umask = File.umask(0o022)
        example.run
      ensure
        File.umask(original_umask)
      end

      it "creates the run's directories accessible only by their owner" do
        allow(Dir).to receive(:pwd).and_return(tmp_dir)

        described_class.resolve(run:)

        modes = [".lba", ".lba/runs"].map { |dir| File.stat(File.join(tmp_dir, dir)).mode & 0o777 }
        expect(modes).to eq([0o700, 0o700])
      end

      it "creates a given path's directory with the usual mode" do
        path = File.join(tmp_dir, "explicit", "sink.jsonl")

        described_class.resolve(sink: path, run:)

        expect(File.stat(File.dirname(path)).mode & 0o777).to eq(0o755)
      end
    end
  end
end
