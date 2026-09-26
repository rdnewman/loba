require "securerandom"

module Lba
  module Internal
    class Run
      class << self
        # A forked child inherits this memo; the pid check gives it its own run
        # and file.
        def current
          return @current if @current&.pid == Process.pid

          @current = new
        end
      end

      attr_reader :id, :started_at, :pid

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
