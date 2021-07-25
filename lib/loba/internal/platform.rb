module Loba
  module Internal
    # Internal class for managing logging across Rails and non-Rails applications
    class Platform
      class << self
        # Returns true if Rails appears to be available
        def rails?
          defined?(Rails) ? true : false
        end

        # Returns true if logging is to be allowed
        def logging_ok?(force_true = false)
          return true if force_true
          return true unless rails?

          begin
            !Rails.env.production?
          rescue StandardError
            true # let it attempt to log anyway
          end
        end

        # Returns a logging mechanism appropriate for the application
        def logger
          if rails? && Rails.logger.present?
            ->(arg) { Rails.logger.debug arg }
          else
            ->(arg) { puts arg }
          end
        end
      end
    end
  end
end
