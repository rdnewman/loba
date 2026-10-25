require "monitor"

module Loba
  module Internal
    class Run
      # Lets one thread at a time into a run's bookkeeping. The thread holding
      # it can take it again, so a Logger or IO that calls loba from within
      # loba's own writing doesn't deadlock.
      class Lock
        def initialize
          @monitor = Monitor.new
        end

        # Runs the block holding the lock, first waiting for any other thread
        # holding it.
        #
        # Ruby raises ThreadError for any wait for a lock in a signal handler.
        # There, a lock another thread holds is passed over and the block runs
        # without it, so tracing a signal handler never raises into it.
        #
        # @return [Object] the block's value
        def synchronize
          entered = enter
          yield
        ensure
          @monitor.mon_exit if entered
        end

      private

        # #try_enter doesn't wait, so it works in a signal handler too.
        def enter
          if @monitor.try_enter
            true
          else
            wait_to_enter
          end
        end

        # Only the wait is rescued; a ThreadError from the block still raises.
        def wait_to_enter
          @monitor.mon_enter
          true
        rescue ThreadError
          false
        end
      end
    end
  end
end
