require "stringio"

RSpec.describe Lba::Internal::Value do
  describe ".record" do
    context "when lba is disabled" do
      before { stub_const("Rails", mock_rails(production: true)) }

      it "does not write anything" do
        sink = StringIO.new

        described_class.record(:foo, sink:)

        expect(sink.string).to be_empty
      end

      it "returns nil" do
        result = described_class.record(:foo)

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

        # Only #file and #line are stubbed, since the site key needs just
        # those. Any other call is the costly work this gate skips; the
        # double raises on it, and the "does not raise" example catches that.
        caller_binding = instance_double(Lba::Internal::CallerBinding, file: "app.rb", line: 10)
        allow(Lba::Internal::CallerBinding).to receive(:new).and_return(caller_binding)

        allow(Lba::Internal::Serialization).to receive(:serialize)
        allow(Lba::Internal::Writer).to receive(:write)
      end

      it "checks the call site's suppression status via the site key" do
        described_class.record(:foo, sink: StringIO.new)

        expect(Lba::Internal::CallSiteTracker.current)
          .to have_received(:record).with("app.rb:10", sink: an_instance_of(StringIO))
      end

      it "does not serialize the value" do
        described_class.record(:foo, sink: StringIO.new)

        expect(Lba::Internal::Serialization).not_to have_received(:serialize)
      end

      it "does not write anything" do
        described_class.record(:foo, sink: StringIO.new)

        expect(Lba::Internal::Writer).not_to have_received(:write)
      end

      it "does not evaluate or reflect on the caller beyond the site key" do
        expect { described_class.record(:foo, sink: StringIO.new) }.not_to raise_error
      end
    end
  end
end
