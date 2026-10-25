RSpec.describe Loba::Internal::Records::Caller do
  describe ".fields" do
    it "describes the calling frame" do
      caller_binding = instance_double(
        Loba::Internal::CallerBinding,
        file: "app/models/order.rb", line: 10, class_name: "Order",
        method_name: "total", method_type: :instance
      )

      fields = described_class.fields(caller_binding)

      expect(fields).to eq(
        file: "app/models/order.rb",
        line: 10,
        class_name: "Order",
        method_name: "total",
        method_type: :instance
      )
    end
  end
end
