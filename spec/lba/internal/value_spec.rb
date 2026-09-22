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

        # Stubbing the class method itself, rather than calling the real
        # .current and stubbing #record on it, so this never touches (or
        # memoizes) the actual process-wide singleton -- doing that would
        # both leak @current state into other spec files and register a
        # real Kernel#at_exit hook against the live test process.
        tracker = instance_double(Lba::Internal::CallSiteTracker, record: :suppressed)
        allow(Lba::Internal::CallSiteTracker).to receive(:current).and_return(tracker)

        # A narrow instance_double: only #file/#line are stubbed, matching what
        # building the site key actually needs. If #record went on to call
        # #evaluate/#class_name/#method_name/#method_type anyway -- the
        # expensive work this gate exists to skip -- this double would raise
        # on that unexpected message, and the "does not raise" example below
        # would catch it.
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
