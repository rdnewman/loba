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

  # Someone opening the file they asked for would otherwise find nothing, and
  # conclude the code never ran.
  describe "#report_fallback" do
    it "warns on $stderr, naming the path and why it couldn't be used" do
      run = described_class.new
      reason = "its directory isn't writable"

      expect { run.report_fallback(path: "/app/trace.jsonl", reason:) }
        .to output(
          "lba: can't use \"/app/trace.jsonl\" (its directory isn't writable); " \
          "writing records to $stdout instead; " \
          "later fallbacks in this process won't be reported\n"
        ).to_stderr
    end

    it "stays quiet about later fallbacks, for any path", :aggregate_failures do
      run = described_class.new
      expect { run.report_fallback(path: "/a.jsonl", reason: "x") }.to output.to_stderr

      expect { run.report_fallback(path: "/b.jsonl", reason: "y") }.not_to output.to_stderr
    end
  end

  describe "#visits" do
    it "is the run's Visits, the same one on every call" do
      run = described_class.new

      expect(run.visits).to be_a(Lba::Internal::Run::Visits).and equal(run.visits)
    end
  end

  describe "#delivery" do
    it "is the run's Delivery, the same one on every call" do
      run = described_class.new

      expect(run.delivery).to be_a(Lba::Internal::Run::Delivery).and equal(run.delivery)
    end
  end

  describe ".current" do
    def order_site = Lba::Internal::Site.new(type: "val", file: "app/models/order.rb", line: 10)

    # A site's cap is 500 records per window, so this leaves one skipped call
    # for the exit hook to write.
    def note_past_cap(run, destination)
      501.times { run.visits.note(order_site, destination:) }
    end

    # A sink on the path whose every append fails.
    def failing_sink(path)
      Lba::Internal::Destination::Sink.new(path).tap do |sink|
        allow(sink).to receive(:append).and_raise(Errno::ENOSPC)
      end
    end

    def fail_quietly(delivery, sink:)
      allow(delivery).to receive(:warn)
      delivery.write({ seq: 3 }, to: sink)
      allow(delivery).to receive(:warn).and_call_original
    end

    it "returns a Run instance" do
      expect(described_class.current).to be_a(described_class)
    end

    it "memoizes the same instance across repeated calls" do
      expect(described_class.current).to equal(described_class.current)
    end

    it "registers one exit hook, the first time it creates the run" do
      described_class.current
      described_class.current

      expect(run_exit_hooks.size).to eq(1)
    end

    it "is the only way a run registers an exit hook" do
      described_class.new

      expect(run_exit_hooks).to be_empty
    end

    context "when its exit hook runs" do
      it "writes the count of calls skipped at a capped site" do
        run = described_class.current
        sink = StringIO.new
        note_past_cap(run, destination_to(sink))

        run_exit_hooks.first.call

        expect(JSON.parse(sink.string.lines.last))
          .to include("suppressed" => true, "suppressed_count" => 1)
      end

      it "summarizes the records that couldn't be written" do
        run = described_class.current
        fail_quietly(run.delivery, sink: failing_sink("a.jsonl"))

        expect { run_exit_hooks.first.call }
          .to output(/lba: 1 record couldn't be written to "a.jsonl"/).to_stderr
      end

      # Summarizing first would lose a record that the hook itself couldn't
      # write.
      it "counts a skipped-call record it couldn't write in the summary" do
        run = described_class.current
        sink = StringIO.new
        note_past_cap(run, destination_to(sink))
        sink.close

        expect { run_exit_hooks.first.call }
          .to output(/lba: 1 record couldn't be written/).to_stderr
      end

      it "still summarizes when writing the skipped-call counts raises" do
        run = described_class.current
        fail_quietly(run.delivery, sink: failing_sink("a.jsonl"))
        allow(run.visits).to receive(:flush).and_raise(RuntimeError, "lba bug")

        expect { run_exit_hooks.first.call }
          .to raise_error(RuntimeError, "lba bug")
          .and output(/lba: 1 record couldn't be written to "a.jsonl"/).to_stderr
      end
    end

    context "when the process forks after .current is memoized" do
      it "gives the child its own run, identified by the child's pid", :aggregate_failures do
        parent_run_id = described_class.current.id

        child = in_forked_child { { pid: Process.pid, run_id: described_class.current.id } }

        expect(child[:run_id]).not_to eq(parent_run_id)
        expect(child[:run_id]).to include("-#{child[:pid]}-")
      end

      it "gives the child fresh visits instead of continuing the parent's" do
        described_class.current.visits.note(order_site)

        child_result = in_forked_child { described_class.current.visits.note(order_site) }

        expect(child_result).to include(seq: 1, site_seq: 1)
      end

      it "gives the child a fresh since_prev_ts instead of timing from the parent's checkpoint" do
        described_class.current.visits.note(order_site, checkpoint: true)

        child_result = in_forked_child do
          described_class.current.visits.note(order_site, checkpoint: true)
        end

        expect(child_result).to include(since_prev_ts: nil)
      end

      it "gives the child a fresh delivery, so it warns about its own first failure" do
        fail_quietly(described_class.current.delivery, sink: failing_sink("a.jsonl"))

        # An expectation inside the child can't report back to the parent, so
        # the child captures $stderr itself and returns what it got.
        warned_in_child = in_forked_child do
          captured = StringIO.new
          $stderr = captured # rubocop:disable RSpec/ExpectOutput
          described_class.current.delivery.write({ seq: 3 }, to: failing_sink("a.jsonl"))
          captured.string
        end

        expect(warned_in_child).to start_with("lba: couldn't write a record")
      end

      it "lets the child warn about its own first fallback" do
        allow(described_class.current).to receive(:warn)
        described_class.current.report_fallback(path: "/a.jsonl", reason: "x")

        warned_in_child = in_forked_child do
          captured = StringIO.new
          $stderr = captured # rubocop:disable RSpec/ExpectOutput
          described_class.current.report_fallback(path: "/a.jsonl", reason: "x")
          captured.string
        end

        expect(warned_in_child).to start_with("lba: can't use")
      end

      it "writes nothing when the child runs the exit hook it inherited" do
        sink = StringIO.new
        note_past_cap(described_class.current, destination_to(sink))

        written_in_child = in_forked_child do
          run_exit_hooks.first.call
          sink.string
        end

        expect(written_in_child).to be_empty
      end

      it "writes no summary when the child runs the exit hook it inherited" do
        fail_quietly(described_class.current.delivery, sink: failing_sink("a.jsonl"))

        summary_in_child = in_forked_child do
          captured = StringIO.new
          $stderr = captured # rubocop:disable RSpec/ExpectOutput
          run_exit_hooks.first.call
          captured.string
        end

        expect(summary_in_child).to be_empty
      end
    end
  end
end
