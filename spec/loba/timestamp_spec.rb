require "json"
require "logger"
require "stringio"

# One call site per caller context Loba.timestamp has to report correctly.
class LobaTsCallerContexts
  def checkpoint(**)
    Loba.timestamp(**)
  end

  CHECKPOINT_LINE = instance_method(:checkpoint).source_location[1] + 1

  def later_checkpoint(sink:)
    Loba.timestamp(sink:)
  end

  def through_alias(sink:)
    Loba.ts(sink:)
  end

  define_method("with_binary_name_\xFF".b) { |sink:| Loba.timestamp(sink:) }
end

RSpec.describe Loba, ".timestamp" do
  def written_record(sink)
    JSON.parse(sink.string, symbolize_names: true)
  end

  # Logger prefixes each line with its own severity and timestamp; the record
  # is the JSON object after that.
  def logged_record(log_output)
    JSON.parse(log_output.string[/\{.*\}/], symbolize_names: true)
  end

  # rubocop:disable-next RSpec/ExampleLength -- one call, one complete record;
  # splitting the field checks would hide that.
  it "writes a complete checkpoint record for the real call site, in a fixed field order",
     :aggregate_failures do
    stub_const("Rails", mock_rails(production: false))
    sink = StringIO.new

    LobaTsCallerContexts.new.checkpoint(sink:)

    record = written_record(sink)
    # The written line is also read raw (tail, grep, truncated output), so its
    # fields come in the same order on every line.
    expect(record.keys).to eq(
      [:seq, :type, :label, :file, :line, :class_name, :method_name, :method_type,
       :site_seq, :since_prev_ts, :wall_time, :mono_time, :run_id, :schema]
    )
    expect(record).to include(
      schema: 1, run_id: Loba::Internal::Run.current.id, seq: 1, type: "ts",
      site_seq: 1, since_prev_ts: nil,
      line: LobaTsCallerContexts::CHECKPOINT_LINE, class_name: "LobaTsCallerContexts",
      method_name: "checkpoint", method_type: "instance", label: nil
    )
    expect(record[:file]).to end_with("timestamp_spec.rb")
    expect(record[:wall_time]).to be_a(Float)
    expect(record[:mono_time]).to be_a(Float)
  end

  it "returns nil" do
    result = LobaTsCallerContexts.new.checkpoint(sink: StringIO.new)

    expect(result).to be_nil
  end

  it "times a checkpoint from the previous one, in another method" do
    sink = StringIO.new
    caller_contexts = LobaTsCallerContexts.new
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)
    caller_contexts.checkpoint(sink:)
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.5)

    caller_contexts.later_checkpoint(sink:)

    second_record = JSON.parse(sink.string.lines.last, symbolize_names: true)
    expect(second_record).to include(method_name: "later_checkpoint", since_prev_ts: 0.5)
  end

  it "times a checkpoint from the previous checkpoint, not from a Loba.value call between" do
    sink = StringIO.new
    caller_contexts = LobaTsCallerContexts.new
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.0)
    caller_contexts.checkpoint(sink:)
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.25)
    described_class.value("between", sink:)
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(100.5)

    caller_contexts.later_checkpoint(sink:)

    last_record = JSON.parse(sink.string.lines.last, symbolize_names: true)
    expect(last_record).to include(since_prev_ts: 0.5)
  end

  it "numbers checkpoints and Loba.value records in one sequence" do
    sink = StringIO.new
    caller_contexts = LobaTsCallerContexts.new
    caller_contexts.checkpoint(sink:)
    described_class.value("between", sink:)

    caller_contexts.later_checkpoint(sink:)

    seqs = sink.string.lines.map { JSON.parse(_1)["seq"] }
    expect(seqs).to eq([1, 2, 3])
  end

  it "times a checkpoint exactly as the gap between the two lines' mono_time" do
    sink = StringIO.new
    caller_contexts = LobaTsCallerContexts.new
    caller_contexts.checkpoint(sink:)

    caller_contexts.later_checkpoint(sink:)

    first, second = sink.string.lines.map { JSON.parse(_1, symbolize_names: true) }
    expect(second[:since_prev_ts]).to eq(second[:mono_time] - first[:mono_time])
  end

  # JSON text is UTF-8, and this once raised into the traced code.
  it "records a calling method's name that isn't valid UTF-8, with U+FFFD for the bad bytes" do
    sink = StringIO.new

    LobaTsCallerContexts.new.public_send("with_binary_name_\xFF".b, sink:)

    expect(written_record(sink)).to include(method_name: "with_binary_name_\uFFFD")
  end

  context "when given a label" do
    it "records it" do
      sink = StringIO.new

      LobaTsCallerContexts.new.checkpoint(label: "reached step A", sink:)

      expect(written_record(sink)).to include(label: "reached step A")
    end
  end

  context "when called by its alias, Loba.ts" do
    it "writes the same kind of record as Loba.timestamp" do
      sink = StringIO.new

      LobaTsCallerContexts.new.through_alias(sink:)

      expect(written_record(sink)).to include(type: "ts", method_name: "through_alias")
    end
  end

  context "when called without the Loba namespace" do
    it "is not available as a bare ts" do
      expect { Object.new.instance_eval { ts } }
        .to raise_error(NameError, /undefined local variable or method [`']ts'/)
    end
  end

  context "when the process forks after an earlier checkpoint" do
    it "writes the child's records under its own run, timed fresh", :aggregate_failures do
      parent_sink = StringIO.new
      LobaTsCallerContexts.new.checkpoint(sink: parent_sink)
      parent_run_id = written_record(parent_sink)[:run_id]

      child_record = in_forked_child do
        child_sink = StringIO.new
        LobaTsCallerContexts.new.checkpoint(sink: child_sink)
        written_record(child_sink)
      end

      expect(child_record[:run_id]).not_to eq(parent_run_id)
      expect(child_record).to include(seq: 1, since_prev_ts: nil)
    end
  end

  # One call writes to the sink and mirrors to the logger: both, not either.
  context "when mirroring to a logger", :aggregate_failures do
    it "writes the same record to the sink and to the given logger" do
      sink = StringIO.new
      log_output = StringIO.new

      LobaTsCallerContexts.new.checkpoint(sink:, logger: Logger.new(log_output))

      expect(written_record(sink)).to include(type: "ts")
      expect(logged_record(log_output)).to eq(written_record(sink))
    end

    it "writes to the sink and to Rails.logger when log: true inside Rails" do
      sink = StringIO.new
      rails_log_output = StringIO.new
      stub_const("Rails", mock_rails(logger: Logger.new(rails_log_output)))

      LobaTsCallerContexts.new.checkpoint(sink:, log: true)

      expect(written_record(sink)).to include(type: "ts")
      expect(logged_record(rails_log_output)).to eq(written_record(sink))
    end

    it "writes only to the sink by default, even inside Rails" do
      sink = StringIO.new
      rails_log_output = StringIO.new
      stub_const("Rails", mock_rails(logger: Logger.new(rails_log_output)))

      LobaTsCallerContexts.new.checkpoint(sink:)

      expect(written_record(sink)).to include(type: "ts")
      expect(rails_log_output.string).to be_empty
    end
  end

  # Run refuses the path and Sink falls back; the promise is the two together.
  context "when a symlink was planted at the run's own file" do
    it "leaves the link's target alone, and sends the record to stdout", :aggregate_failures do
      hide_const("Rails")
      Dir.mktmpdir do |dir|
        target = File.join(dir, "target")
        File.write(target, "someone else's file\n")

        output = output_with_symlink_at_run_file(target) { described_class.timestamp }

        expect(File.read(target)).to eq("someone else's file\n")
        expect(JSON.parse(output[:stdout], symbolize_names: true)).to include(type: "ts")
        expect(output[:stderr]).to include("writing records to $stdout instead")
      end
    end
  end

  # Misusing loba's own API fails loudly at the line just written.
  context "when misused" do
    it "raises for an option it doesn't take, such as production:" do
      expect { described_class.timestamp(production: true) }
        .to raise_error(ArgumentError, /unknown keyword: :production/)
    end

    it "raises when logger: is not a Logger" do
      expect { described_class.timestamp(logger: "not a logger", sink: StringIO.new) }
        .to raise_error(Loba::InvalidLoggerOptionError)
    end
  end
end
