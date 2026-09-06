class PoroWithNestedCall < InstanceTestCase
  def outer
    inner
  end

private

  def inner
    subject.method_name
  end
end

RSpec.describe Lba::Internal::CallerBinding do
  # depth: 1 to skip past #inner and land on its caller, #outer.
  subject(:caller_binding) { described_class.new(depth: 1) }

  context "when called one method removed from the target frame" do
    it "reports the outer caller, not the intermediate method" do
      poro = PoroWithNestedCall.with(caller_binding)

      expect(poro.outer).to eq(:outer)
    end
  end
end
