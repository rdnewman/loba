# Some parts of a value are recorded as text rather than as themselves. The
# text can look exactly like a real String, so :rendered names each such part
# by its path and says why it's text.
RSpec.describe Loba::Internal::Serialization do
  describe ".serialize :rendered" do
    def object_rendering(inspect: "#<Thing inspected>", to_s: "#<Thing to_s>")
      Object.new.tap do |object|
        object.define_singleton_method(:inspect) { inspect }
        object.define_singleton_method(:to_s) { to_s }
      end
    end

    def rendered(value, inspect: true)
      described_class.serialize(value:, inspect:)[:rendered]
    end

    it "is absent when every part was recorded as itself" do
      result = described_class.serialize(value: { "total" => [1, "x", nil, 2.5] })

      expect(result).not_to have_key(:rendered)
    end

    describe "why a part is text" do
      it "is inspect for an object with no JSON form" do
        expect(rendered(object_rendering)).to eq([{ path: [], as: "inspect" }])
      end

      it "is to_s for the same, with inspect: false" do
        expect(rendered(object_rendering, inspect: false)).to eq([{ path: [], as: "to_s" }])
      end

      it "is non_finite for NaN or Infinity", :aggregate_failures do
        expect(rendered(Float::NAN)).to eq([{ path: [], as: "non_finite" }])
        expect(rendered(-Float::INFINITY)).to eq([{ path: [], as: "non_finite" }])
      end

      it "is not_utf8 for a String that isn't, and can't become, UTF-8" do
        expect(rendered("caf\xE9".b)).to eq([{ path: [], as: "not_utf8" }])
      end

      it "is too_deep for a container nested too deeply, rendered whole" do
        expect(rendered([[[[[[1]]]]]])).to eq([{ path: [0, 0, 0, 0, 0], as: "too_deep" }])
      end
    end

    describe "where a part is" do
      it "is [] for the whole value" do
        expect(rendered(object_rendering)).to eq([{ path: [], as: "inspect" }])
      end

      it "is its index in an Array" do
        expect(rendered([1, object_rendering])).to eq([{ path: [1], as: "inspect" }])
      end

      it "is its key, as JSON writes it, in a Hash" do
        expect(rendered({ total: Float::NAN })).to eq([{ path: ["total"], as: "non_finite" }])
      end

      # Otherwise a rendered key and a rendered value under it would read the
      # same, and a real String value could be taken for rendered text.
      it "is the pair's path, marked key: true, for a key" do
        expect(rendered({ object_rendering => "hello" }))
          .to eq([{ path: ["#<Thing inspected>"], as: "inspect", key: true }])
      end

      # JSON holds a key only as text, so a path into a key's insides would
      # lead nowhere.
      it "is one entry for a container key, rendered whole" do
        expect(rendered({ [1, object_rendering] => "v" }))
          .to eq([{ path: ["[1, #<Thing inspected>]"], as: "inspect", key: true }])
      end

      it "is every key and index down to it, when nested" do
        expect(rendered({ items: [1, object_rendering] }))
          .to eq([{ path: ["items", 1], as: "inspect" }])
      end
    end

    it "lists every rendered part, in order" do
      value = [object_rendering, 1, Float::NAN]

      expect(rendered(value)).to eq([{ path: [0], as: "inspect" }, { path: [2], as: "non_finite" }])
    end

    # A part whose rendering raised is recorded in :errors; one signal per
    # condition.
    it "leaves out a part whose rendering raised", :aggregate_failures do
      result = described_class.serialize(value: [BasicObject.new, object_rendering])

      expect(result[:rendered]).to eq([{ path: [1], as: "inspect" }])
      expect(result[:errors].map { _1[:path] }).to eq([[0]])
    end
  end
end
