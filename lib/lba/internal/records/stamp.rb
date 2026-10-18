require_relative "../run"

module Lba
  module Internal
    module Records
      # The bookkeeping fields every record closes with: when it was written,
      # its run, and its format version. They come last because they matter
      # least when reading a line raw, and +run_id+ and +schema+ repeat on every
      # line.
      module Stamp
        # The record format's version.
        SCHEMA = 1

        # @param mono_time [Float] the monotonic clock reading to record; read
        #   now if not given
        # @return [Hash{Symbol => Object}] +:wall_time+ (seconds since the
        #   epoch), +:mono_time+, +:run_id+, and +:schema+, in that order
        def self.fields(mono_time: Process.clock_gettime(Process::CLOCK_MONOTONIC))
          {
            wall_time: Time.now.to_f,
            mono_time:,
            run_id: Run.current.id,
            schema: SCHEMA
          }
        end
      end
    end
  end
end
