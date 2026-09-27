require_relative "run"

module Lba
  module Internal
    # The fields every record opens with: its format version, run, order,
    # kind, and when it was written.
    module RecordStamp
      # The record format's version.
      SCHEMA = 1

      # @param seq [Integer] the record's order among all the process's records
      # @param type [String] the kind of record, e.g. +"val"+
      # @return [Hash{Symbol => Object}] +:schema+, +:run_id+, +:seq+, +:type+,
      #   +:wall_time+ (seconds since the epoch), and +:mono_time+ (a monotonic
      #   clock reading), in that order
      def self.fields(seq:, type:)
        {
          schema: SCHEMA,
          run_id: Run.current.id,
          seq:,
          type:,
          wall_time: Time.now.to_f,
          mono_time: Process.clock_gettime(Process::CLOCK_MONOTONIC)
        }
      end
    end
  end
end
