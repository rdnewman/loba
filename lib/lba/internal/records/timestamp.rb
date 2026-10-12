require_relative "../record_stamp"
require_relative "../label"
require_relative "caller"

module Lba
  module Internal
    module Records
      # Builds a checkpoint record's fields.
      class Timestamp
        # The record type.
        TYPE = "ts".freeze

        # Each call is a checkpoint, timed from the previous one.
        CHECKPOINT = true

        # Builds the record's fields; shorthand for +new(...).fields+.
        #
        # @return (see #fields)
        def self.fields(...) = new(...).fields

        # @param caller_binding [CallerBinding] the calling frame
        # @param tracked [Hash{Symbol => Integer, Float, nil}] the call's numbers
        #   and timing (see Run::Visits#record)
        # @param label [String, Symbol, nil] the label given, if any
        def initialize(caller_binding:, tracked:, label:)
          @caller_binding = caller_binding
          @tracked = tracked
          @label = label
        end

        # @return [Hash{Symbol => Object}] the record's fields, in order
        def fields
          {
            seq: tracked[:seq],
            type: TYPE,
            label: Label.infer(argument: nil, label:),
            **Caller.fields(caller_binding),
            site_seq: tracked[:site_seq],
            since_prev_ts: tracked[:since_prev_ts],
            **RecordStamp.fields(mono_time: tracked[:mono_time])
          }
        end

      private

        attr_reader :caller_binding, :tracked, :label
      end
    end
  end
end
