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

  context "when called from a class method on an anonymous class" do
    it 'returns "<anonymous class>" for class_name' do
      anonymous_class = Class.new(ClassTestCase).as_class_using(caller_binding)

      expect(anonymous_class.class_name).to eq("<anonymous class>")
    end
  end
end
