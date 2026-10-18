require "logger"
require "stringio"

RSpec.describe Lba::Internal::Invocation do
  describe ".record" do
    context "when lba is disabled" do
      before { stub_const("Rails", mock_rails(production: true)) }

      it "does not write anything" do
        sink = StringIO.new

        described_class.record(Lba::Internal::Records::Timestamp, sink:)

        expect(sink.string).to be_empty
      end

      it "does not snapshot the caller" do
        allow(Lba::Internal::CallerBinding).to receive(:capture)

        described_class.record(Lba::Internal::Records::Timestamp)

        expect(Lba::Internal::CallerBinding).not_to have_received(:capture)
      end

      it "returns nil" do
        result = described_class.record(Lba::Internal::Records::Timestamp)

        expect(result).to be_nil
      end

      it "does not validate the logger given" do
        expect { described_class.record(Lba::Internal::Records::Timestamp, logger: "not a logger") }
          .not_to raise_error
      end

      it "does not resolve the sink, so it never touches the filesystem" do
        Dir.mktmpdir do |dir|
          sink_dir = File.join(dir, "never_created")

          described_class.record(
            Lba::Internal::Records::Timestamp, sink: File.join(sink_dir, "records.jsonl")
          )

          expect(Dir.exist?(sink_dir)).to be false
        end
      end
    end

    context "when the call site is suppressed" do
      before do
        stub_const("Rails", mock_rails(production: false))
        visits = instance_double(Lba::Internal::Run::Visits, note: :suppressed)
        allow(Lba::Internal::Run.current).to receive(:visits).and_return(visits)

        # Only #file and #line are stubbed, since the call site needs just
        # those. Any other call is the costly work this gate skips; the
        # double raises on it, and the "does not raise" example catches that.
        caller_binding = instance_double(Lba::Internal::CallerBinding, file: "app.rb", line: 10)
        allow(Lba::Internal::CallerBinding).to receive(:capture).and_return(caller_binding)

        allow(Lba::Internal::Records::Timestamp).to receive(:fields)
      end

      it "tells the run's visits a timestamp call is a checkpoint" do
        destination = destination_to(StringIO.new)
        allow(Lba::Internal::Destination).to receive(:for).and_return(destination)

        described_class.record(Lba::Internal::Records::Timestamp, sink: StringIO.new)

        expect(Lba::Internal::Run.current.visits).to have_received(:note)
          .with(
            Lba::Internal::Site.new(type: "ts", file: "app.rb", line: 10),
            destination:, checkpoint: true
          )
      end

      it "tells the run's visits a value call isn't a checkpoint" do
        destination = destination_to(StringIO.new)
        allow(Lba::Internal::Destination).to receive(:for).and_return(destination)
        options = { argument: :total, label: nil, inspect: true }

        described_class.record(Lba::Internal::Records::Value, options:, sink: StringIO.new)

        expect(Lba::Internal::Run.current.visits).to have_received(:note)
          .with(
            Lba::Internal::Site.new(type: "val", file: "app.rb", line: 10),
            destination:, checkpoint: false
          )
      end

      it "does not build the record" do
        described_class.record(Lba::Internal::Records::Timestamp, sink: StringIO.new)

        expect(Lba::Internal::Records::Timestamp).not_to have_received(:fields)
      end

      it "does not write anything" do
        sink = StringIO.new

        described_class.record(Lba::Internal::Records::Timestamp, sink:)

        expect(sink.string).to be_empty
      end

      it "does not reflect on the caller beyond its file and line" do
        expect { described_class.record(Lba::Internal::Records::Timestamp, sink: StringIO.new) }
          .not_to raise_error
      end
    end

    context "when the call is recorded" do
      let(:caller_binding) do
        instance_double(Lba::Internal::CallerBinding, file: "app.rb", line: 10)
      end
      let(:tracked) { { seq: 1, site_seq: 1, diff: nil, since_prev_ts: nil } }

      before do
        stub_const("Rails", mock_rails(production: false))
        visits = instance_double(Lba::Internal::Run::Visits, note: tracked)
        allow(Lba::Internal::Run.current).to receive(:visits).and_return(visits)
        allow(Lba::Internal::CallerBinding).to receive(:capture).and_return(caller_binding)
        allow(Lba::Internal::Records::Timestamp)
          .to receive(:fields).and_return({ type: "ts", seq: 1 })
      end

      it "builds the record from the caller, the visit's numbers, and the options given" do
        described_class.record(
          Lba::Internal::Records::Timestamp, options: { label: "step A" }, sink: StringIO.new
        )

        expect(Lba::Internal::Records::Timestamp).to have_received(:fields)
          .with(caller_binding:, tracked:, label: "step A")
      end

      it "builds one destination for the call, from the options given" do
        sink = StringIO.new
        allow(Lba::Internal::Destination).to receive(:for).and_call_original

        described_class.record(Lba::Internal::Records::Timestamp, options: { label: nil }, sink:)

        expect(Lba::Internal::Destination)
          .to have_received(:for).once.with(sink:, log: nil, logger: nil)
      end

      it "writes the record's fields to the sink as one JSON line" do
        sink = StringIO.new

        described_class.record(Lba::Internal::Records::Timestamp, options: { label: nil }, sink:)

        expect(sink.string).to eq("{\"type\":\"ts\",\"seq\":1}\n")
      end

      it "writes the same JSON to the logger when logging" do
        log_output = StringIO.new

        described_class.record(
          Lba::Internal::Records::Timestamp,
          options: { label: nil }, logger: Logger.new(log_output), sink: StringIO.new
        )

        expect(log_output.string).to include('{"type":"ts","seq":1}')
      end

      it "returns nil" do
        result = described_class.record(
          Lba::Internal::Records::Timestamp, options: { label: nil }, sink: StringIO.new
        )

        expect(result).to be_nil
      end
    end

    # An invocation's own steps run none of the caller's code, so a failure in them
    # is lba's own bug and surfaces rather than being recorded.
    context "when lba itself fails" do
      it "raises into the calling code" do
        stub_const("Rails", mock_rails(production: false))
        visits = instance_double(Lba::Internal::Run::Visits)
        allow(visits).to receive(:note).and_raise(RuntimeError, "visits bug")
        allow(Lba::Internal::Run.current).to receive(:visits).and_return(visits)

        expect { described_class.record(Lba::Internal::Records::Timestamp, sink: StringIO.new) }
          .to raise_error(RuntimeError, "visits bug")
      end
    end
  end
end
