class NamedRubyClass < ClassTestCase; end

RSpec.describe Lba::Internal::CallerBinding do
  subject(:caller_binding) { described_class.new }

  context "when called from a class method" do
    after { NamedRubyClass.reset_subject }

    it "reports :class for method_type" do
      named_class = NamedRubyClass.as_class_using(caller_binding)

      expect(named_class.method_type).to eq(:class)
    end
  end
end
