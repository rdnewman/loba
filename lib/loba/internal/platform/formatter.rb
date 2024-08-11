require 'logger'
require 'English'

module Loba
  module Internal
    module Platform
      # Custom logging formatter (for when Rails is not involved)
      class Formatter
        def initialize(*); end

        # Formats supplied message to write to logger.
        #
        # This formatter ignores +severity+, +time+, and +progname+ because it enforces
        # that Loba messages are written out to the log without additional ornamentation.
        #
        # @param msg [String] Loba content to write out
        # @return [String] message formatted for writing to log
        def call(_severity, _time, _progname, msg)
          "#{msg2str(msg)}#{$INPUT_RECORD_SEPARATOR}"
        end

        private

        def msg2str(msg)
          case msg
          when ::String
            msg
          when ::Exception
            "#{msg.message} (#{msg.class})\n#{msg.backtrace&.join("\n")}"
          else
            msg.inspect
          end
        end
      end
    end
  end
end
