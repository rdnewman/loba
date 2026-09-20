class PoroWithLocalVariable < InstanceTestCase
  def report_local_number
    local_number = 123 # rubocop:disable Lint/UselessAssignment -- read via CallerBinding#evaluate
    subject.evaluate(:local_number)
  end
end

RSpec.describe Lba::Internal::CallerBinding do
  subject(:caller_binding) { described_class.new }

  context "when evaluating a symbol against the caller's local variables" do
    it "returns the local variable's value" do
      poro = PoroWithLocalVariable.with(caller_binding)

      expect(poro.report_local_number).to eq(123)
    end
  end

  context "when evaluating a non-symbol argument" do
    it "returns the argument unchanged without evaluating it as code" do
      invalid_ruby_code = "this is not valid ruby !!"

      expect(caller_binding.evaluate(invalid_ruby_code)).to equal(invalid_ruby_code)
    end
  end
end
