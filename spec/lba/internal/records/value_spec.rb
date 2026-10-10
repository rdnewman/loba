RSpec.describe Lba::Internal::Records::Value do
  def caller_binding(evaluates_to: 129.5)
    instance_double(
      Lba::Internal::CallerBinding,
      file: "app/models/order.rb", line: 55, class_name: "Order",
      method_name: "total", method_type: :instance, evaluate: evaluates_to
    )
  end

  def tracked = { seq: 7, site_seq: 2, diff: 0.4 }

  it "is the val record type" do
    expect(described_class::TYPE).to eq("val")
  end

  describe ".fields" do
    it "has the stamp, the site's number and diff, the caller, a label, and the value" do
      fields = described_class.fields(
        caller_binding:, tracked:, argument: :subtotal, label: nil, inspect: true
      )

      expect(fields.keys).to contain_exactly(
        :schema, :run_id, :seq, :type, :wall_time, :mono_time, :site_seq, :diff,
        :file, :line, :class_name, :method_name, :method_type,
        :label, :value, :value_type, :inspected, :truncated
      )
    end

    it "takes its numbers and timing from the tracker" do
      fields = described_class.fields(
        caller_binding:, tracked:, argument: :subtotal, label: nil, inspect: true
      )

      expect(fields).to include(seq: 7, type: "val", site_seq: 2, diff: 0.4)
    end

    it "records the value the argument evaluates to in the caller, labeled by the Symbol" do
      fields = described_class.fields(
        caller_binding:, tracked:, argument: :subtotal, label: nil, inspect: true
      )

      expect(fields).to include(label: "subtotal", value: 129.5, value_type: "Float")
    end

    it "renders a value with no JSON form using #to_s when inspect: is false" do
      unrepresentable = Object.new
      def unrepresentable.to_s = "as text"

      fields = described_class.fields(
        caller_binding: caller_binding(evaluates_to: unrepresentable),
        tracked:,
        argument: :thing,
        label: nil,
        inspect: false
      )

      expect(fields).to include(value: "as text", inspected: true)
    end

    context "when evaluating the argument raises" do
      it "records the error in place of the value, keeping the label", :aggregate_failures do
        failing_binding = caller_binding
        allow(failing_binding).to receive(:evaluate).and_raise(NameError, "undefined name")

        fields = described_class.fields(
          caller_binding: failing_binding, tracked:, argument: :usr, label: nil, inspect: true
        )

        expect(fields).to include(label: "usr", error: "NameError: undefined name")
        expect(fields.keys).not_to include(:value, :value_type, :inspected, :truncated)
      end

      it "lets exceptions outside StandardError, such as Interrupt, through" do
        interrupting_binding = caller_binding
        allow(interrupting_binding).to receive(:evaluate).and_raise(Interrupt)

        expect do
          described_class.fields(
            caller_binding: interrupting_binding, tracked:,
            argument: :usr, label: nil, inspect: true
          )
        end.to raise_error(Interrupt)
      end
    end
  end
end
