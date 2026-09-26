require "securerandom"

module Lba
  # lba's implementation, behind the public +Lba.val+. Not part of the public
  # API; any of it may change.
  module Internal
    # One process's run: every record it writes carries the run's id, and its
    # records share one sink file.
    class Run
      class << self
        # This process's run, created on first use.
        #
        # A forked child inherits this memo; the pid check gives it its own run
        # and file.
        #
        # @return [Run]
        def current
          return @current if @current&.pid == Process.pid

          @current = new
        end
      end

      # @return [String] the run's id: a UTC timestamp, the process id, and four
      #   random hex digits, e.g. +"20260926T210626Z-894825-b10f"+
      attr_reader :id

      attr_reader :started_at

      # @return [Integer] the id of the process that started the run
      attr_reader :pid

      # Starts a run for the current process.
      def initialize
        @pid = Process.pid
        @id = generate_id
        @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

    private

      def generate_id
        timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
        "#{timestamp}-#{pid}-#{SecureRandom.hex(2)}"
      end
    end
  end
end
