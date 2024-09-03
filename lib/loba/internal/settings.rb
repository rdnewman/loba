module Loba
  module Internal
    # Internal class for tracking output and logging settings based on supplied options
    class Settings
      # @return [boolean] whether logging is performed
      attr_reader :log
      alias log? log

      # @return [Logger] +::Logger+ used for logging; may be +nil+ if not logging
      attr_reader :logger

      # @return [nil, String, IO, File::NULL]
      #   any custom (overridden) logging device being written to; +nil+ if none specified
      attr_reader :logdev

      # @return [boolean] +false+ if console output is suppressed; otherwise, +true+
      attr_reader :out
      alias out? out

      # @return [boolean]
      #   +true+ if Loba is enabled even within a Rails production environment; otherwise, +false+
      attr_reader :production
      alias production? production

      # @param log [boolean]
      #   set to +false+ if no logging is ever wanted
      #   (default when not in Rails and +logger+ is nil);
      #   set to +true+ if logging is always wanted (default when in Rails or
      #   when +logger+ is set or +out+ is false);
      # @param logger [Logger] override logging with specified Ruby Logger
      # @param logdev [nil, String, IO, File::NULL]
      #   custom log device to use (when not in Rails); ignored if +logger+ is set;
      #   must be filename or IO object
      # @param out [boolean]
      #   set to +false+ if console output is to be suppressed
      # @param production [boolean]
      #   set to +true+ if Loba is to work even within a Rails production environment
      # @note To avoid doubled output, if a non-Rails logger is to be logged to and +logdev+ is
      #   set to +$stdout+, then output will be suppressed (i.e., +settings.out+ is +false+).
      #   Doubled output can still occur; in that case, explicitly use +out: false+.
      # @raise [InvalidLoggerOptionError] when an invalid logger is specified
      # @raise [InvalidLogdevOptionError] when an invalid logdev is specified
      def initialize(log: nil, logger: nil, logdev: nil, out: true, production: false)
        @raw_log_argument = log
        @log = validated_log(log)
        @out = false
        @production = validated_production(production)

        return unless enabled?

        @logger = validated_logger(logger)
        @logdev = validated_logdev(logdev)
        @out = validated_out(out)

        configure_logging
      end

      # @return [Boolean] +true+ if Loba is used; otherwise, +false+
      def enabled?
        production? || !Internal::Platform::WithinRails.production?
      end

      # @return [Boolean] +true+ if Loba is skipped (because of a production environment);
      #   otherwise, +false+
      def disabled?
        !enabled?
      end

      private

      attr_reader :raw_log_argument

      def validated_log(candidate_log)
        Internal.boolean_cast(candidate_log)
      end

      def validated_logger(candidate_logger)
        return if candidate_logger.nil?
        raise InvalidLoggerOptionError unless candidate_logger.is_a?(::Logger)

        @log = true unless log_explicit?

        candidate_logger
      end

      def validated_logdev(candidate_logdev)
        case candidate_logdev
        when nil, String, IO, StringIO, File::NULL
          candidate_logdev
        else
          raise InvalidLogdevOptionError
        end
      end

      def validated_out(candidate_out)
        will_output = !logging_to_stdout? && out_param_cast(candidate_out)

        @log = true unless will_output || log_explicit?

        will_output
      end

      def validated_production(candidate_production)
        Internal.boolean_cast(candidate_production)
      end

      def log_explicit?
        !raw_log_argument.nil?
      end

      def logging_to_stdout?
        log? && ((logdev == $stdout) || (logdev == '$stdout'))
      end

      def configure_logging
        @log &&= enabled?

        @logger ||= default_logger if log?
      end

      def default_logger
        if Internal::Platform::WithinRails.logger?
          ::Rails.logger
        else
          ::Logger.new((logdev || $stdout), formatter: Internal::Platform::Formatter.new)
        end
      end

      def out_param_cast(value)
        case value
        when true, TrueClass
          true
        when nil, false, FalseClass, File::NULL
          false
        when String, Integer, IO, StringIO
          Internal.boolean_cast(value)
        else
          raise InvalidOutOptionError
        end
      end
    end
  end
end
