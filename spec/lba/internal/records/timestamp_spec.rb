RSpec.describe Lba::Internal::Records::Timestamp do
  def caller_binding
    instance_double(
      Lba::Internal::CallerBinding,
      file: "app/models/cart.rb", line: 3, class_name: "Cart",
      method_name: "checkout", method_type: :instance
    )
  end

  it "is the ts record type" do
    expect(described_class::TYPE).to eq("ts")
  end

  it "marks its calls as checkpoints" do
    expect(described_class::CHECKPOINT).to be(true)
  end

  describe ".fields" do
    it "has the stamp, the site's number, the timing since the previous ts, the caller, " \
       "and a label, with no site diff" do
      tracked = { seq: 7, mono_time: 100.25, site_seq: 2, diff: 0.4, since_prev_ts: 0.25 }

      fields = described_class.fields(caller_binding:, tracked:, label: nil)

      expect(fields.keys).to contain_exactly(
        :schema, :run_id, :seq, :type, :wall_time, :mono_time, :site_seq, :since_prev_ts,
        :file, :line, :class_name, :method_name, :method_type, :label
      )
    end

    it "takes its numbers and timing from the run's visits" do
      tracked = { seq: 7, mono_time: 100.25, site_seq: 2, diff: 0.4, since_prev_ts: 0.25 }

      fields = described_class.fields(caller_binding:, tracked:, label: nil)

      expect(fields)
        .to include(seq: 7, type: "ts", mono_time: 100.25, site_seq: 2, since_prev_ts: 0.25)
    end

    it "records the label given, normalized" do
      tracked = { seq: 1, mono_time: 100.25, site_seq: 1, diff: nil, since_prev_ts: nil }

      fields = described_class.fields(caller_binding:, tracked:, label: "  card charged ")

      expect(fields).to include(label: "card charged")
    end
  end
end
