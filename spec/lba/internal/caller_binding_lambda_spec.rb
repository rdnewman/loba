# __method__ resolves by lexical position, not by what dynamically calls it --
# a block/lambda nested inside a real `def` still reports that def's name,
# even though the lambda itself is (like every lambda) unnamed as an object.
class PoroWithEnclosedLambda < InstanceTestCase
  def method_name
    enclosed_lambda = lambda do
      subject.method_name
    end

    enclosed_lambda.call
  end
end

RSpec.describe Lba::Internal::CallerBinding do
  subject(:caller_binding) { described_class.new }

  describe "#method_name called within a lambda" do
    context "when defined within an enclosing method" do
      it "returns the enclosing method's real name" do
        poro = PoroWithEnclosedLambda.instance_with(caller_binding)

        expect(poro.method_name).to eq(:method_name)
      end
    end

    # A real, if rare, way this could be invoked in the wild (a bare script, a
    # top-level rake task body) -- not the 80% case, but not metaprogramming
    # either: it's the actual scenario under test, not a construction shortcut.
    context "when defined outside an enclosing method" do
      it 'returns "<anonymous method>"' do
        bare_lambda = lambda do
          caller_binding.method_name
        end

        expect(bare_lambda.call).to eq("<anonymous method>")
      end
    end
  end
end
