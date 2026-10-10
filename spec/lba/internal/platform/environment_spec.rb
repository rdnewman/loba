RSpec.describe Lba::Internal::Platform::Environment do
  # Sets real environment variables for one example and restores them after,
  # so the examples don't depend on how the code reads ENV.
  around do |example|
    names = ["RACK_ENV", "APP_ENV", "RAILS_ENV"]
    saved = names.to_h { |name| [name, ENV.delete(name)] }
    example.run
  ensure
    saved.each { |name, value| ENV[name] = value }
  end

  describe ".production?" do
    context "when Rails is loaded" do
      it "is true when Rails says production" do
        stub_const("Rails", mock_rails(production: true))

        expect(described_class.production?).to be true
      end

      it "follows Rails over the environment variables" do
        stub_const("Rails", mock_rails(production: false))
        ENV["RACK_ENV"] = "production"

        expect(described_class.production?).to be false
      end
    end

    context "when Rails isn't loaded" do
      before { hide_const("Rails") }

      it "is true when RACK_ENV is production" do
        ENV["RACK_ENV"] = "production"

        expect(described_class.production?).to be true
      end

      it "is true when APP_ENV is production" do
        ENV["APP_ENV"] = "production"

        expect(described_class.production?).to be true
      end

      it "is true when RAILS_ENV is production" do
        ENV["RAILS_ENV"] = "production"

        expect(described_class.production?).to be true
      end

      it "is false when none of them is production" do
        ENV["RACK_ENV"] = "development"

        expect(described_class.production?).to be false
      end
    end

    # Gems such as rails-html-sanitizer define a Rails namespace without Rails.
    context "when only a Rails namespace is defined" do
      it "goes by the environment variables" do
        stub_const("Rails", Module.new)
        ENV["RACK_ENV"] = "production"

        expect(described_class.production?).to be true
      end
    end
  end
end
