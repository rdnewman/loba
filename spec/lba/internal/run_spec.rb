require "fileutils"
require "securerandom"

RSpec.describe Lba::Internal::Run do
  describe "#id" do
    it "combines a UTC timestamp, the process id, and a random hex suffix" do
      allow(Time).to receive(:now).and_return(Time.utc(2026, 8, 30, 14, 30, 12))
      allow(Process).to receive(:pid).and_return(4242)
      allow(SecureRandom).to receive(:hex).with(4).and_return("ab12cd34")

      run = described_class.new

      expect(run.id).to eq("20260830T143012Z-4242-ab12cd34")
    end

    it "memoizes the id across repeated calls" do
      run = described_class.new
      first_id = run.id

      allow(SecureRandom).to receive(:hex).and_return("ffff")

      expect(run.id).to eq(first_id)
    end
  end

  describe "#claim_file" do
    let(:tmp_dir) { Dir.mktmpdir }

    around do |example|
      original_umask = File.umask(0o022)
      example.run
    ensure
      File.umask(original_umask)
    end

    after { FileUtils.remove_entry(tmp_dir) }

    it "creates the file, readable and writable only by its owner", :aggregate_failures do
      path = File.join(tmp_dir, "run.jsonl")

      claimed = described_class.new.claim_file(path)

      expect(claimed).to be true
      expect(File.stat(path).mode & 0o777).to eq(0o600)
    end

    it "keeps claiming a file it already created" do
      path = File.join(tmp_dir, "run.jsonl")
      run = described_class.new
      run.claim_file(path)

      expect(run.claim_file(path)).to be true
    end

    it "claims a second path separately, as after a chdir", :aggregate_failures do
      first_path = File.join(tmp_dir, "first.jsonl")
      second_path = File.join(tmp_dir, "second.jsonl")
      run = described_class.new
      run.claim_file(first_path)

      claimed = run.claim_file(second_path)

      expect(claimed).to be true
      expect(File.exist?(second_path)).to be true
    end

    # Someone with write access to the directory could plant a symlink at the
    # run's path, so that records are appended to a file of their choosing.
    it "refuses a symlink already at the path, leaving its target alone", :aggregate_failures do
      target = File.join(tmp_dir, "target")
      File.write(target, "original")
      path = File.join(tmp_dir, "run.jsonl")
      File.symlink(target, path)

      claimed = described_class.new.claim_file(path)

      expect(claimed).to be false
      expect(File.read(target)).to eq("original")
    end

    it "refuses a dangling symlink already at the path", :aggregate_failures do
      target = File.join(tmp_dir, "target")
      path = File.join(tmp_dir, "run.jsonl")
      File.symlink(target, path)

      claimed = described_class.new.claim_file(path)

      expect(claimed).to be false
      expect(File.exist?(target)).to be false
    end

    it "refuses a file already at the path" do
      path = File.join(tmp_dir, "run.jsonl")
      File.write(path, "")

      expect(described_class.new.claim_file(path)).to be false
    end

    it "refuses a path whose directory doesn't exist" do
      path = File.join(tmp_dir, "missing", "run.jsonl")

      expect(described_class.new.claim_file(path)).to be false
    end
  end

  describe ".current" do
    after { reset_current(described_class) }

    it "returns a Run instance" do
      expect(described_class.current).to be_a(described_class)
    end

    it "memoizes the same instance across repeated calls" do
      expect(described_class.current).to equal(described_class.current)
    end

    context "when the process forks after .current is memoized" do
      it "gives the child its own run, identified by the child's pid", :aggregate_failures do
        parent_run_id = described_class.current.id

        child = in_forked_child { { pid: Process.pid, run_id: described_class.current.id } }

        expect(child[:run_id]).not_to eq(parent_run_id)
        expect(child[:run_id]).to include("-#{child[:pid]}-")
      end
    end
  end
end
