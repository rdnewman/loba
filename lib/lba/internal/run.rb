require "securerandom"

module Lba
  module Internal
    class Run
      class << self
        def current
          @current ||= new
        end
      end

      attr_reader :id, :started_at

      def initialize
        @id = generate_id
        @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

    private

      def generate_id
        timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
        "#{timestamp}-#{Process.pid}-#{SecureRandom.hex(2)}"
      end
    end
  end
end
