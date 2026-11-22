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

    # json writes a String tagged binary but holding valid UTF-8, with a
    # deprecation warning on the traced program's $stderr.
    it "reads caller text that's tagged binary as UTF-8", :aggregate_failures do
      caller_binding = instance_double(
        Loba::Internal::CallerBinding,
        file: "caf\xC3\xA9.rb".b, line: 10, class_name: "Caf\xC3\xA9".b,
        method_name: "caf\xC3\xA9".b.to_sym, method_type: :instance
      )

      fields = described_class.fields(caller_binding)

      expect(fields.values_at(:file, :class_name, :method_name)).to eq(["café.rb", "Café", "café"])
      expect(fields.values_at(:file, :class_name, :method_name).map(&:encoding).uniq)
        .to eq([Encoding::UTF_8])
    end
  end
end
