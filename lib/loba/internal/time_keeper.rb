require 'singleton'

module Loba
  module Internal
    # Internal class for tracking time stamps; should not be used directly
    # @!attribute [rw] timewas
    #   Previous timestamped Time value
    # @!attribute [rw] timenum
    #   Count of timestamping occurances so far
    class TimeKeeper
      include Singleton
      attr_accessor :timewas, :timenum

      def initialize
        @timewas = Time.now
        @timenum = 0
      end

      def ping
        @timenum += 1
        now = Time.now
        change = now - @timewas
        @timewas = now

        { number: @timenum, now: now, change: change }
      end
    end
  end
end
