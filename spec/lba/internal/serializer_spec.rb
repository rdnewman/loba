RSpec.describe Lba::Internal::Serializer do
  describe ".serialize", :aggregate_failures do
    context "with a JSON-native scalar" do
      it "passes an Integer through unchanged" do
        result = described_class.serialize(42)

        expect(result).to eq(
          value: 42,
          value_type: "Integer",
          inspected: false,
          truncated: false
        )
      end

      it "passes a Float through unchanged" do
        result = described_class.serialize(3.14)

        expect(result).to eq(
          value: 3.14,
          value_type: "Float",
          inspected: false,
          truncated: false
        )
      end

      it "passes a String through unchanged" do
        result = described_class.serialize("hello")

        expect(result).to eq(
          value: "hello",
          value_type: "String",
          inspected: false,
          truncated: false
        )
      end

      it "passes true through unchanged" do
        result = described_class.serialize(true)

        expect(result).to eq(
          value: true,
          value_type: "TrueClass",
          inspected: false,
          truncated: false
        )
      end

      it "passes false through unchanged" do
        result = described_class.serialize(false)

        expect(result).to eq(
          value: false,
          value_type: "FalseClass",
          inspected: false,
          truncated: false
        )
      end

      it "passes nil through unchanged" do
        result = described_class.serialize(nil)

        expect(result).to eq(
          value: nil,
          value_type: "NilClass",
          inspected: false,
          truncated: false
        )
      end

      # Symbol isn't a JSON type, but JSON.generate coerces it to a string
      # automatically (Writer's job, not Serializer's) -- value_type still
      # preserves that this was originally a Symbol, not a String.
      it "passes a Symbol through unchanged" do
        result = described_class.serialize(:foo)

        expect(result).to eq(
          value: :foo,
          value_type: "Symbol",
          inspected: false,
          truncated: false
        )
      end
    end

    context "with a value that isn't JSON-native" do
      it "falls back to #inspect" do
        plain_object = Object.new

        result = described_class.serialize(plain_object)

        expect(result).to eq(
          value: plain_object.inspect,
          value_type: "Object",
          inspected: true,
          truncated: false
        )
      end
    end

    context "with a container (Hash/Array)" do
      it "passes a Hash of native values through unchanged" do
        result = described_class.serialize({ a: 1, b: "two" })

        expect(result).to eq(
          value: { a: 1, b: "two" },
          value_type: "Hash",
          inspected: false,
          truncated: false
        )
      end

      it "passes an Array of native values through unchanged" do
        result = described_class.serialize([1, "two", true])

        expect(result).to eq(
          value: [1, "two", true],
          value_type: "Array",
          inspected: false,
          truncated: false
        )
      end

      it "recursively substitutes a non-native entry and aggregates inspected: true" do
        plain_object = Object.new

        result = described_class.serialize({ a: 1, b: plain_object })

        expect(result).to eq(
          value: { a: 1, b: plain_object.inspect },
          value_type: "Hash",
          inspected: true,
          truncated: false
        )
      end
    end

    context "when nesting depth is at or beyond MAX_DEPTH" do
      def nested_array(levels, leaf: "leaf")
        levels.zero? ? leaf : [nested_array(levels - 1, leaf:)]
      end

      it "recurses fully through exactly MAX_DEPTH levels of nesting" do
        just_fits = nested_array(described_class::MAX_DEPTH)

        result = described_class.serialize(just_fits)

        expect(result[:inspected]).to be false
        expect(result[:value]).to eq(just_fits)
      end

      it "falls back to #inspect for the container one level past MAX_DEPTH" do
        too_deep = nested_array(described_class::MAX_DEPTH + 1)

        result = described_class.serialize(too_deep)

        expect(result[:inspected]).to be true
        expect(result[:value]).to eq([[[[["[\"leaf\"]"]]]]])
      end

      it "terminates safely for a circular structure instead of recursing forever" do
        circular = []
        circular << circular

        result = described_class.serialize(circular)

        expect(result[:inspected]).to be true
        expect(result[:value]).to eq([[[[["[[...]]"]]]]])
      end
    end

    context "with an oversized String" do
      it "truncates to MAX_STRING_LENGTH chars with a continuation marker" do
        long_string = "a" * (described_class::MAX_STRING_LENGTH + 523)

        result = described_class.serialize(long_string)

        expect(result[:value]).to eq("#{'a' * described_class::MAX_STRING_LENGTH} [+523 chars]")
        expect(result[:value_type]).to eq("String")
        expect(result[:inspected]).to be false
        expect(result[:truncated]).to be true
      end

      it "does not truncate a String at exactly MAX_STRING_LENGTH" do
        exact_length_string = "a" * described_class::MAX_STRING_LENGTH

        result = described_class.serialize(exact_length_string)

        expect(result[:value]).to eq(exact_length_string)
        expect(result[:truncated]).to be false
      end
    end

    context "with an oversized Array" do
      it "truncates to MAX_ENTRIES elements with a continuation marker" do
        long_array = Array.new(described_class::MAX_ENTRIES + 7) { |i| i }

        result = described_class.serialize(long_array)

        expected_value = (0...described_class::MAX_ENTRIES).to_a + ["[+7 more entries]"]
        expect(result[:value]).to eq(expected_value)
        expect(result[:value_type]).to eq("Array")
        expect(result[:inspected]).to be false
        expect(result[:truncated]).to be true
      end

      it "does not truncate an Array at exactly MAX_ENTRIES" do
        exact_size_array = Array.new(described_class::MAX_ENTRIES) { |i| i }

        result = described_class.serialize(exact_size_array)

        expect(result[:value]).to eq(exact_size_array)
        expect(result[:truncated]).to be false
      end
    end

    context "with an oversized Hash" do
      it "truncates to MAX_ENTRIES pairs with a continuation marker" do
        long_hash = (0...(described_class::MAX_ENTRIES + 7)).to_h { |i| [i, i] }

        result = described_class.serialize(long_hash)

        kept_pairs = (0...described_class::MAX_ENTRIES).to_h { |i| [i, i] }
        expected_value = kept_pairs.merge("[+7 more keys]" => true)

        expect(result[:value]).to eq(expected_value)
        expect(result[:value_type]).to eq("Hash")
        expect(result[:inspected]).to be false
        expect(result[:truncated]).to be true
      end

      it "does not truncate a Hash at exactly MAX_ENTRIES" do
        exact_size_hash = (0...described_class::MAX_ENTRIES).to_h { |i| [i, i] }

        result = described_class.serialize(exact_size_hash)

        expect(result[:value]).to eq(exact_size_hash)
        expect(result[:truncated]).to be false
      end
    end
  end
end
