# __method__ is lexical: a lambda inside a `def` reports that def's name,
# though the lambda itself has none.
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

    # Rare but real: a bare script or a top-level rake task body.
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
