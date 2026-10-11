require "logger"
require "stringio"

RSpec.describe Lba::Internal::Trace do
  describe ".record" do
    context "when lba is disabled" do
      before { stub_const("Rails", mock_rails(production: true)) }

      it "does not write anything" do
        sink = StringIO.new

        described_class.record(Lba::Internal::Records::Timestamp, sink:)

        expect(sink.string).to be_empty
      end

      it "does not snapshot the caller" do
        allow(Lba::Internal::CallerBinding).to receive(:new)

        described_class.record(Lba::Internal::Records::Timestamp)

        expect(Lba::Internal::CallerBinding).not_to have_received(:new)
      end

      it "returns nil" do
        result = described_class.record(Lba::Internal::Records::Timestamp)

        expect(result).to be_nil
      end
    end

    context "when the call site is suppressed" do
      before do
        stub_const("Rails", mock_rails(production: false))

        # Stubs .current itself so the real singleton is never memoized and
        # never registers an at_exit hook in the test process.
        tracker = instance_double(Lba::Internal::Tracker, record: :suppressed)
        allow(Lba::Internal::Tracker).to receive(:current).and_return(tracker)

        # Only #file and #line are stubbed, since the call site needs just
        # those. Any other call is the costly work this gate skips; the
        # double raises on it, and the "does not raise" example catches that.
        caller_binding = instance_double(Lba::Internal::CallerBinding, file: "app.rb", line: 10)
        allow(Lba::Internal::CallerBinding).to receive(:new).and_return(caller_binding)

        allow(Lba::Internal::Records::Timestamp).to receive(:fields)
      end

      it "tells the tracker a timestamp call is a checkpoint" do
        described_class.record(Lba::Internal::Records::Timestamp, sink: StringIO.new)

        expect(Lba::Internal::Tracker.current).to have_received(:record)
          .with(
            Lba::Internal::Site.new(type: "ts", file: "app.rb", line: 10),
            sink: an_instance_of(StringIO), checkpoint: true
          )
      end

      it "tells the tracker a value call isn't a checkpoint" do
        options = { argument: :total, label: nil, inspect: true }

        described_class.record(Lba::Internal::Records::Value, options:, sink: StringIO.new)

        expect(Lba::Internal::Tracker.current).to have_received(:record)
          .with(
            Lba::Internal::Site.new(type: "val", file: "app.rb", line: 10),
            sink: an_instance_of(StringIO), checkpoint: false
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
        tracker = instance_double(Lba::Internal::Tracker, record: tracked)
        allow(Lba::Internal::Tracker).to receive(:current).and_return(tracker)
        allow(Lba::Internal::CallerBinding).to receive(:new).and_return(caller_binding)
        allow(Lba::Internal::Records::Timestamp)
          .to receive(:fields).and_return({ type: "ts", seq: 1 })
      end

      it "builds the record from the caller, the tracker's numbers, and the options given" do
        described_class.record(
          Lba::Internal::Records::Timestamp, options: { label: "step A" }, sink: StringIO.new
        )

        expect(Lba::Internal::Records::Timestamp).to have_received(:fields)
          .with(caller_binding:, tracked:, label: "step A")
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

    # A trace's own steps run none of the caller's code, so a failure in them
    # is lba's own bug and surfaces rather than being recorded.
    context "when lba itself fails" do
      it "raises into the calling code" do
        stub_const("Rails", mock_rails(production: false))
        tracker = instance_double(Lba::Internal::Tracker)
        allow(tracker).to receive(:record).and_raise(RuntimeError, "tracker bug")
        allow(Lba::Internal::Tracker).to receive(:current).and_return(tracker)

        expect { described_class.record(Lba::Internal::Records::Timestamp, sink: StringIO.new) }
          .to raise_error(RuntimeError, "tracker bug")
      end
    end
  end
end
