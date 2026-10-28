RSpec.describe Loba::Internal::Serialization::FloatNode do
  describe ".serialize" do
    it "records a finite Float as itself" do
      result = described_class.serialize(value: 3.14)

      expect(result).to eq(value: 3.14, value_type: "Float")
    end

    # JSON has no NaN or Infinity, so these are recorded as text.
    [Float::NAN, Float::INFINITY, -Float::INFINITY].each do |non_finite|
      it "records #{non_finite} as text" do
        result = described_class.serialize(value: non_finite)

        expect(result).to eq(
          value: non_finite.to_s, value_type: "Float", rendered: [{ path: [], as: "non_finite" }]
        )
      end
    end
  end
end
