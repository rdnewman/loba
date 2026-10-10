require "fileutils"
require "pathname"
require "stringio"

RSpec.describe Lba::Internal::SinkResolver, :aggregate_failures do
  let(:run) { instance_double(Lba::Internal::Run, id: "20260830T143012Z-4242-ab12") }
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
  end
end
