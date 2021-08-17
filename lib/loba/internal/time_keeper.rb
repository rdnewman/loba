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

      def ping
        @timenum += 1
        now = Time.now
        change = now - @timewas
        @timewas = now

        { number: @timenum, now: now, change: change }
      end

      def reset!
        @timewas = Time.now
        @timenum = 0
      end
    end
  end
end
