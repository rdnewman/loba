RSpec.describe Lba::Internal::Site do
  it "requires a type, file, and line, with no defaults" do
    expect { described_class.new(file: "app/models/order.rb", line: 10) }
      .to raise_error(ArgumentError, /type/)
  end

  # The tracker keeps each site's state in a Hash keyed by the site, building
  # a new Site for every call.
  describe "as a Hash key" do
    it "finds a site's entry with another site of the same type, file, and line" do
      sites = { described_class.new(type: "val", file: "app/models/order.rb", line: 10) => :found }

      entry = sites[described_class.new(type: "val", file: "app/models/order.rb", line: 10)]

      expect(entry).to eq(:found)
    end

    it "keeps sites that differ in type, file, or line apart", :aggregate_failures do
      site = described_class.new(type: "val", file: "app/models/order.rb", line: 10)
      sites = { site => :found }

      expect(sites[site.with(type: "ts")]).to be_nil
      expect(sites[site.with(file: "app/models/invoice.rb")]).to be_nil
      expect(sites[site.with(line: 11)]).to be_nil
    end
  end
end
