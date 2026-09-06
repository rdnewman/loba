class PlainOldRubyObject < InstanceTestCase; end
class SubclassOfPlainOldRubyObject < PlainOldRubyObject; end

RSpec.describe Lba::Internal::CallerBinding do
  subject(:caller_binding) { described_class.new }

  context "when called from an ordinary instance method" do
    it "returns the real class name" do
      poro = PlainOldRubyObject.with(caller_binding)

      expect(poro.class_name).to eq("PlainOldRubyObject")
    end

    it "reports :instance for method_type" do
      poro = PlainOldRubyObject.with(caller_binding)

      expect(poro.method_type).to eq(:instance)
    end

    it "matches a caller-style path:line:in-method string for source_line" do
      poro = PlainOldRubyObject.with(caller_binding)
      expected = /instance_test_case\.rb:\d+:in .*source_line/

      expect(poro.source_line).to match(expected)
    end
  end

  context "when called from an instance of an anonymous class" do
    it 'returns "<anonymous class>" for class_name' do
      anonymous_class = Class.new(InstanceTestCase)
      instance = anonymous_class.instance_with(caller_binding)

      expect(instance.class_name).to eq("<anonymous class>")
    end
  end

  context "when called from a subclass using an inherited method" do
    it "returns the subclass's real class name, not the ancestor's" do
      subclass_instance = SubclassOfPlainOldRubyObject.with(caller_binding)

      expect(subclass_instance.class_name).to eq("SubclassOfPlainOldRubyObject")
    end
  end
end
