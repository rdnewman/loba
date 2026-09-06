module Lba
  module Internal
    class Serializer
      NATIVE_TYPES = [
        Integer, Float, String, TrueClass, FalseClass, NilClass, Symbol
      ].freeze

      # Containers recurse up to this many levels before falling back to
      # #inspect. This also bounds a circular structure's recursion -- it
      # can't exceed MAX_DEPTH regardless of the cycle, and Ruby's own
      # #inspect handles the resulting cycle safely once recursion stops.
      #
      # 5 is an unvalidated placeholder, not a measured value -- there's no
      # performance data yet showing where cost actually starts to matter.
      # Revisit once the Phase 4 overhead benchmark exists to inform it.
      MAX_DEPTH = 5

      # A String longer than this is cut to exactly this many characters,
      # then has a "[+N chars]" marker appended showing how many were
      # dropped -- the marker's own length isn't counted against this limit.
      #
      # 500 is an unvalidated placeholder, same caveat as MAX_DEPTH above:
      # no performance data yet showing where cost actually starts to matter.
      MAX_STRING_LENGTH = 500

      # A Hash/Array with more than this many entries has the rest dropped,
      # then gets one trailing sentinel entry appended showing how many were
      # dropped -- entries beyond this limit are never even recursed into,
      # so a huge accidental value doesn't cost more than this to process.
      #
      # 50 is an unvalidated placeholder, same caveat as MAX_DEPTH above: no
      # performance data yet showing where cost actually starts to matter.
      MAX_ENTRIES = 50

      def self.serialize(...) = new(...).serialize

      def initialize(value, depth: 0)
        @value = value
        @depth = depth
      end

      def serialize
        if (hash? || array?) && depth < MAX_DEPTH
          serialize_container
        elsif native?
          serialize_native
        else
          { value: value.inspect, value_type: value_type, inspected: true, truncated: false }
        end
      end

    private

      attr_reader :value, :depth

      def serialize_container
        if hash?
          serialize_hash
        else
          serialize_array
        end
      end

      def serialize_native
        if string? && value.length > MAX_STRING_LENGTH
          { value: truncated_string, value_type: value_type, inspected: false, truncated: true }
        else
          { value: value, value_type: value_type, inspected: false, truncated: false }
        end
      end

      def truncated_string
        omitted = value.length - MAX_STRING_LENGTH
        "#{value[0...MAX_STRING_LENGTH]} [+#{omitted} chars]"
      end

      def hash? = value.is_a?(Hash)

      def array? = value.is_a?(Array)

      def string? = value.is_a?(String)

      def native?
        NATIVE_TYPES.any? { |type| value.instance_of?(type) }
      end

      def value_type
        value.class.name
      end

      def serialize_hash
        results = kept_entries.transform_values do |entry|
          self.class.serialize(entry, depth: depth + 1)
        end
        substituted = results.transform_values { |result| result[:value] }
        substituted["[+#{omitted_count} more keys]"] = true if oversized?

        aggregate(substituted, results.values, self_truncated: oversized?)
      end

      def serialize_array
        results = kept_entries.map { |entry| self.class.serialize(entry, depth: depth + 1) }
        substituted = results.map { |result| result[:value] }
        substituted << "[+#{omitted_count} more entries]" if oversized?

        aggregate(substituted, results, self_truncated: oversized?)
      end

      def oversized?
        value.size > MAX_ENTRIES
      end

      def omitted_count
        value.size - MAX_ENTRIES
      end

      def kept_entries
        return value unless oversized?

        value.is_a?(Hash) ? value.first(MAX_ENTRIES).to_h : value.first(MAX_ENTRIES)
      end

      # Substitutes each entry's own serialized value in place -- preserving
      # the container's shape, rather than falling back to one #inspect
      # string for the whole thing -- and aggregates inspected/truncated:
      # true if *anything* in the tree needed it (including the container
      # itself, via self_truncated), not only if every entry did.
      def aggregate(substituted_value, sub_results, self_truncated: false)
        {
          value: substituted_value,
          value_type: value_type,
          inspected: sub_results.any? { |result| result[:inspected] },
          truncated: self_truncated || sub_results.any? { |result| result[:truncated] }
        }
      end
    end
  end
end
