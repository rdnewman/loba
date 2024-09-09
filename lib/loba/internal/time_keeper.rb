require 'singleton'

module Loba
  module Internal
    # Internal class for tracking time stamps; should not be used directly
    # @!attribute [r] timewas
    #   Previous timestamped Time value
    # @!attribute [r] timenum
    #   Count of timestamping occurances so far
    class TimeKeeper
      include Singleton
      attr_reader :timewas, :timenum

      def initialize
        reset!
      end

      # Increments timestamping, including attributes +timenum+ and +timewas+
      # @return [Hash] timestamp details
      #   * :number => [Integer] incremented count of pings so far (attribute +timenum+)
      #   * :now => [Time] current date and time
      #   * :change => [Float] difference in seconds from any previous ping or reset
      def ping
        @timenum += 1
        now = Time.now
        change = now - @timewas
        @timewas = now

        { number: @timenum, now: now, change: change }
      end

      # Resets timestamping
      # @return [NilClass] nil
      def reset!
        @timewas = Time.now
        @timenum = 0

        nil
      end
    end
  end
end
