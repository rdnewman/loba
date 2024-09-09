require 'logger'
require 'English'

module Loba
  module Internal
    module Platform
      # Custom logging formatter (for when Rails is not involved)
      class Formatter
        # Formats supplied message to write to logger.
        #
        # This formatter ignores +severity+, +time+, and +progname+ because it enforces
        # that Loba messages are written out to the log without additional ornamentation.
        #
        # @param message [String] Loba content to write out
        # @return [String] message formatted for writing to log
        def call(_severity, _time, _progname, message)
          "#{format(message)}#{$INPUT_RECORD_SEPARATOR}"
        end

        private

        def format(message)
          case message
          when ::String
            message
          when ::Exception
            format_exception(message)
          else
            message.inspect
          end
        end

        def format_exception(err)
          backtrace = err.backtrace
          result = "#{err.message} (#{err.class})"
          return result if backtrace.to_s.empty?

          result + "\n#{backtrace}"
        end
      end
    end
  end
end
