# The smallest concrete container: its children are its entries, and its
# value lists their serialized values.
class ListContainerNode < Lba::Internal::Serialization::ContainerNode
private

  def value_type = "List"

  def children_of(entries) = entries

  def values = children.map { _1[:value] }

  def position(index) = index
end

RSpec.describe Lba::Internal::Serialization::ContainerNode do
  describe ".serialize", :aggregate_failures do
    def oversized_string
      "a" * (Lba::Internal::Serialization::StringNode::MAX_LENGTH + 1)
    end

    it "returns its value and type, not truncated, for plain entries" do
      result = ListContainerNode.serialize(value: [1, "two"])

      expect(result).to eq(
        value: [1, "two"], value_type: "List", truncated: false
      )
    end

    # Truncated if any child is. A first child and a later one each catch code
    # that keeps only one child's flag.
    context "when a child is truncated" do
      it "is truncated when any child is, even the first" do
        result = ListContainerNode.serialize(value: [oversized_string, 1])

        expect(result[:truncated]).to be true
      end

      it "is truncated when a later child is" do
        result = ListContainerNode.serialize(value: [Object.new, 1, oversized_string])

        expect(result[:truncated]).to be true
      end
    end

    context "when given more than MAX_ENTRIES entries" do
      it "is truncated even when no child is" do
        entries = Array.new(described_class::MAX_ENTRIES + 1) { 1 }

        result = ListContainerNode.serialize(value: entries)

        expect(result[:truncated]).to be true
      end

      it "never serializes the entries past the limit" do
        entries = Array.new(described_class::MAX_ENTRIES) { 1 } + [Object.new]

        result = ListContainerNode.serialize(value: entries)

        expect(result[:value].size).to eq(described_class::MAX_ENTRIES)
      end
    end

    context "when given exactly MAX_ENTRIES entries" do
      it "is not truncated" do
        entries = Array.new(described_class::MAX_ENTRIES) { 1 }

        result = ListContainerNode.serialize(value: entries)

        expect(result[:truncated]).to be false
      end
    end

    describe "its children" do
      it "are serialized one level deeper, so a child can reach the depth limit" do
        max_depth = described_class::MAX_DEPTH

        within_limit = ListContainerNode.serialize(value: [[1]], depth: max_depth - 2)
        at_limit = ListContainerNode.serialize(value: [[1]], depth: max_depth - 1)

        expect(within_limit).to include(value: [[1]])
        expect(at_limit).to include(value: ["[1]"])
      end

      it "are serialized with the given use_inspect" do
        object = object_with_distinct_inspect

        result = ListContainerNode.serialize(value: [object], use_inspect: false)

        expect(result[:value]).to eq([object.to_s])
      end
    end

    context "when at or beyond MAX_DEPTH" do
      it "falls back to #inspect for itself" do
        result = ListContainerNode.serialize(value: [1], depth: described_class::MAX_DEPTH)

        expect(result).to include(value: "[1]")
      end

      it "cuts a long #inspect of itself and flags it truncated" do
        long_entries = Array.new(Lba::Internal::Serialization::StringNode::MAX_LENGTH) { 1 }

        result = ListContainerNode.serialize(value: long_entries, depth: described_class::MAX_DEPTH)

        expect(result[:value]).to end_with(" chars]")
        expect(result[:truncated]).to be true
      end

      # Its own output is #inspect either way, so only skipping the walk shows.
      it "never serializes its children" do
        allow(Lba::Internal::Serialization::UnknownNode).to receive(:serialize).and_call_original

        ListContainerNode.serialize(value: [[1]], depth: described_class::MAX_DEPTH)

        expect(Lba::Internal::Serialization::UnknownNode).not_to have_received(:serialize)
      end

      it "forwards use_inspect to the fallback" do
        max_depth = described_class::MAX_DEPTH
        allow(Lba::Internal::Serialization::FallbackNode).to receive(:serialize).and_call_original

        ListContainerNode.serialize(value: [1], depth: max_depth, use_inspect: false)

        expect(Lba::Internal::Serialization::FallbackNode).to have_received(:serialize).with(
          value: [1], depth: max_depth, use_inspect: false, as: "too_deep"
        )
      end
    end

    context "when the value contains itself" do
      it "stops at the depth limit instead of recursing forever" do
        circular = []
        circular << circular

        result = ListContainerNode.serialize(value: circular)

        expect(result).to include(value: [[[[["[[...]]"]]]]])
      end
    end
  end
end
