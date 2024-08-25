require_relative 'platform/formatter'

module Loba
  module Internal
    # Internal module for managing logging across Rails and non-Rails applications
    module Platform
      class << self
        # Checks if logging output is allowed.
        # @return [Boolean] true if logging is to be allowed; otherwise, false
        def logging_allowed?(force_true = false)
          return true if force_true
          return true unless rails?

          begin
            !Rails.env.production?
          rescue StandardError
            true # let it attempt to log anyway
          end
        end

        # Provides logging mechanism appropriate in the application.
        #
        # If in Rails and a Rails logger is available, then the +logdev+ argument will be ignored.
        #
        # When given and not in Rails, the logger will use the +logdev+ argument. This is
        # passed directly to Ruby's +Logger+ class and so has the same restrictions. It then must
        # be one of:
        #
        # - A string filepath: entries are to be written to the file at that path; if the file at
        #   that path exists, new entries are appended.
        # - An IO stream (typically +$stdout+, +$stderr+. or an open file): entries are to be
        #   written to the given stream.
        # - +nil+ or +File::NULL+: no entries are to be written.
        #
        # Returned lambda takes 2 arguments:
        #   * arg [String] value to be output (and potentially logged)
        #   * force_log [Boolean] when false (default), never logs to the configured logger;
        #       when true, logs to the configured logger if present
        #
        # @param logdev [NilClass|String|IO] When not in Rails, the logging device to write to
        # @return [Lambda] procedure for logging output
        def writer(options:)
          will_log = false
          if options.log
            will_log = rails_logger? && logging_allowed?(options.log)
            logger = options.logger || default_logger(options.logdev)
          end

          lambda do |arg|
            puts(arg) if options.out?

            logger.debug arg if will_log
          end
        end

        private

        # Determine a default logger to use
        #
        # @param logdev [NilClass|String|IO] When not in Rails, the logging device to write to
        # @return [Object<Logger>] default logger to write to
        def default_logger(logdev)
          if rails_logger?
            Rails.logger
          else
            ::Logger.new(logdev, formatter: Loba::Internal::Platform::Formatter.new)
          end
        end

        # Checks if Rails is present
        # @return [Boolean] true if Rails appears to be available; otherwise, false
        def rails?
          defined?(Rails) ? true : false
        end

        def rails_logger?
          rails? && Rails.logger.present?
        end
      end
    end
  end
end
