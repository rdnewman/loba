module Loba
  module Internal
    # Internal class for managing logging across Rails and non-Rails applications
    class Platform
      class << self
        # Checks if Rails is present
        # @return [Boolean] true if Rails appears to be available; otherwise, false
        def rails?
          defined?(Rails) ? true : false
        end

        # Checks if logging output is permitted.
        # @return [Boolean] true if logging is to be allowed; otherwise, false
        def logging_ok?(force_true = false)
          return true if force_true
          return true unless rails?

          begin
            !Rails.env.production?
          rescue StandardError
            true # let it attempt to log anyway
          end
        end

        # Provides logging mechanism appropriate in the application
        # @return [Lambda] procedure for logging output
        def logger
          if rails? && Rails.logger.present?
            ->(arg) { puts arg; Rails.logger.debug arg }
          else
            ->(arg) { puts arg }
          end
        end
      end
    end
  end
end
