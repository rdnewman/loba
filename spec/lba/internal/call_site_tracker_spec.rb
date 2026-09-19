RSpec.describe Lba::Internal::CallSiteTracker do
  subject(:tracker) { described_class.new }

  describe "#record" do
    it "assigns seq 1 and site_seq 1 to a call site's first record" do
      result = tracker.record("app/models/order.rb:10", value: 42)

      expect(result).to include(seq: 1, site_seq: 1)
    end

    it "marks a site's first record as changed, with no previous value" do
      result = tracker.record("app/models/order.rb:10", value: 42)

      expect(result).to include(changed: true, prev_value: nil)
    end

    it "increments both seq and site_seq on a second call to the same site" do
      tracker.record("app/models/order.rb:10", value: 1)

      result = tracker.record("app/models/order.rb:10", value: 2)

      expect(result).to include(seq: 2, site_seq: 2)
    end

    it "marks changed: true and reports the previous value when the value differs" do
      tracker.record("app/models/order.rb:10", value: 1)

      result = tracker.record("app/models/order.rb:10", value: 2)

      expect(result).to include(changed: true, prev_value: 1)
    end

    it "marks changed: false when the value is unchanged from the previous call" do
      tracker.record("app/models/order.rb:10", value: 1)

      result = tracker.record("app/models/order.rb:10", value: 1)

      expect(result).to include(changed: false, prev_value: 1)
    end

    it "tracks site_seq independently per call site" do
      tracker.record("app/models/order.rb:10", value: 1)
      tracker.record("app/models/order.rb:10", value: 2)

      result = tracker.record("app/models/invoice.rb:20", value: 1)

      expect(result).to include(site_seq: 1)
    end

    it "shares one global seq counter across call sites" do
      tracker.record("app/models/order.rb:10", value: 1)

      result = tracker.record("app/models/invoice.rb:20", value: 1)

      expect(result).to include(seq: 2)
    end

    it "tracks the previous value independently per call site" do
      tracker.record("app/models/order.rb:10", value: 1)

      result = tracker.record("app/models/invoice.rb:20", value: 99)

      expect(result).to include(changed: true, prev_value: nil)
    end
  end

  describe ".current" do
    after { described_class.instance_variable_set(:@current, nil) }

    it "returns a CallSiteTracker instance" do
      expect(described_class.current).to be_a(described_class)
    end

    it "memoizes the same instance across repeated calls" do
      expect(described_class.current).to equal(described_class.current)
    end
  end
end
