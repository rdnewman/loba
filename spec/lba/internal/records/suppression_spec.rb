RSpec.describe Lba::Internal::Records::Suppression do
  describe ".fields" do
    it "counts the site's skipped calls under the given seq" do
      site = Lba::Internal::Site.new(type: "ts", file: "app/models/order.rb", line: 10)

      fields = described_class.fields(site:, suppressed_count: 7, seq: 42)

      expect(fields).to include(
        seq: 42, type: "ts", file: "app/models/order.rb", line: 10,
        suppressed: true, suppressed_count: 7
      )
    end

    it "carries the same stamp as every record" do
      site = Lba::Internal::Site.new(type: "val", file: "app/models/order.rb", line: 10)

      fields = described_class.fields(site:, suppressed_count: 1, seq: 1)

      expect(fields).to include(
        schema: 1, run_id: Lba::Internal::Run.current.id,
        wall_time: a_kind_of(Float), mono_time: a_kind_of(Float)
      )
    end
  end
end
