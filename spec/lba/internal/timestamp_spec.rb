require "stringio"

RSpec.describe Lba::Internal::Timestamp do
  describe ".record" do
    context "when lba is disabled" do
      before { stub_const("Rails", mock_rails(production: true)) }

      it "does not write anything" do
        sink = StringIO.new

        described_class.record(sink:)

        expect(sink.string).to be_empty
      end

      it "returns nil" do
        result = described_class.record

        expect(result).to be_nil
      end
    end

    context "when the call site is suppressed" do
      before do
        stub_const("Rails", mock_rails(production: false))

        # Stubs .current itself so the real singleton is never memoized and
        # never registers an at_exit hook in the test process.
        tracker = instance_double(Lba::Internal::CallSiteTracker, record: :suppressed)
        allow(Lba::Internal::CallSiteTracker).to receive(:current).and_return(tracker)

        # Only #file and #line are stubbed, since the call site needs just
        # those. Any other call is the costly work this gate skips; the
        # double raises on it, and the "does not raise" example catches that.
        caller_binding = instance_double(Lba::Internal::CallerBinding, file: "app.rb", line: 10)
        allow(Lba::Internal::CallerBinding).to receive(:new).and_return(caller_binding)

        allow(Lba::Internal::Writer).to receive(:write)
      end

      it "checks the call site's suppression status as a ts site" do
        described_class.record(sink: StringIO.new)

        expect(Lba::Internal::CallSiteTracker.current).to have_received(:record)
          .with(type: "ts", file: "app.rb", line: 10, sink: an_instance_of(StringIO))
      end

      it "does not write anything" do
        described_class.record(sink: StringIO.new)

        expect(Lba::Internal::Writer).not_to have_received(:write)
      end

      it "does not reflect on the caller beyond its file and line" do
        expect { described_class.record(sink: StringIO.new) }.not_to raise_error
      end
    end

    # A ts runs none of the caller's code, so a failure is lba's own bug and
    # surfaces rather than being recorded.
    context "when lba itself fails" do
      it "raises into the calling code" do
        stub_const("Rails", mock_rails(production: false))
        tracker = instance_double(Lba::Internal::CallSiteTracker)
        allow(tracker).to receive(:record).and_raise(RuntimeError, "tracker bug")
        allow(Lba::Internal::CallSiteTracker).to receive(:current).and_return(tracker)

        expect { described_class.record(sink: StringIO.new) }
          .to raise_error(RuntimeError, "tracker bug")
      end
    end
  end
end
