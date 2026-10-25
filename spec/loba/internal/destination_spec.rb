require "json"
require "logger"
require "stringio"

RSpec.describe Loba::Internal::Destination do
  describe ".for" do
    it "writes to the IO given as the sink" do
      sink = StringIO.new
      destination = described_class.for(sink:, log: nil, logger: nil)

      destination.write({ seq: 1 })

      expect(sink.string).to eq("{\"seq\":1}\n")
    end

    it "writes to the file at the path given as the sink" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "records.jsonl")
        destination = described_class.for(sink: path, log: nil, logger: nil)

        destination.write({ seq: 1 })

        expect(File.read(path)).to eq("{\"seq\":1}\n")
      end
    end

    context "when no sink is given" do
      around do |example|
        original_loba_sink = ENV.delete("LOBA_SINK")
        example.run
      ensure
        ENV["LOBA_SINK"] = original_loba_sink if original_loba_sink
      end

      it "writes to the run's own file" do
        hide_const("Rails")
        Dir.mktmpdir do |dir|
          allow(Dir).to receive(:pwd).and_return(dir)
          destination = described_class.for(sink: nil, log: nil, logger: nil)

          destination.write({ seq: 1 })

          path = File.join(dir, ".loba", "runs", "#{Loba::Internal::Run.current.id}.jsonl")
          expect(File.read(path)).to eq("{\"seq\":1}\n")
        end
      end
    end

    it "mirrors to the logger given" do
      log_output = StringIO.new
      destination = described_class.for(
        sink: StringIO.new, log: nil, logger: Logger.new(log_output)
      )

      destination.write({ seq: 1 })

      expect(log_output.string).to include("{\"seq\":1}")
    end

    it "raises for an invalid logger before touching the filesystem", :aggregate_failures do
      Dir.mktmpdir do |dir|
        sink_dir = File.join(dir, "never_created")

        expect do
          described_class.for(
            sink: File.join(sink_dir, "records.jsonl"), log: true, logger: "not a logger"
          )
        end.to raise_error(Loba::InvalidLoggerOptionError)
        expect(Dir.exist?(sink_dir)).to be false
      end
    end

    it "mirrors nothing when log: is false, even with a logger given" do
      log_output = StringIO.new
      destination = described_class.for(
        sink: StringIO.new, log: false, logger: Logger.new(log_output)
      )

      destination.write({ seq: 1 })

      expect(log_output.string).to be_empty
    end
  end

  describe "#write" do
    it "appends the record to the sink as a JSON line" do
      io = StringIO.new
      sink = Loba::Internal::Destination::Sink.new(io)
      destination = described_class.new(sink:, log_mirror: nil)

      destination.write({ seq: 1, type: "ts" })

      expect(io.string).to eq("{\"seq\":1,\"type\":\"ts\"}\n")
    end

    it "also writes the same JSON to the logger, at debug level", :aggregate_failures do
      log_output = StringIO.new
      logger = Logger.new(log_output, level: :debug)
      log_mirror = Loba::Internal::Destination::LogMirror.new(logger:)
      sink = Loba::Internal::Destination::Sink.new(StringIO.new)
      destination = described_class.new(sink:, log_mirror:)

      destination.write({ seq: 1, type: "ts" })

      expect(log_output.string).to include("DEBUG")
      expect(log_output.string).to include("{\"seq\":1,\"type\":\"ts\"}")
    end

    # The log has every record the sink missed, so the sink's gap isn't noted
    # there.
    it "mirrors each record as given, even when the sink missed some", :aggregate_failures do
      io = StringIO.new
      failures = 1
      allow(io).to receive(:write).and_wrap_original do |original, line|
        raise Errno::ENOSPC if (failures -= 1) >= 0

        original.call(line)
      end
      log_output = StringIO.new
      log_mirror = Loba::Internal::Destination::LogMirror.new(logger: Logger.new(log_output))
      sink = Loba::Internal::Destination::Sink.new(io)
      destination = described_class.new(sink:, log_mirror:)
      allow(Loba::Internal::Run.current.recorder).to receive(:warn)

      [1, 2].each { |seq| destination.write({ seq: }) }

      expect(io.string).to include("unwritten")
      expect(log_output.string.lines.map { _1[/\{.*\}/] }).to eq(["{\"seq\":1}", "{\"seq\":2}"])
    end
  end
end
