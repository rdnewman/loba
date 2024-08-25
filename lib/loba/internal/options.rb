module Loba
  module Internal
    # Internal class for tracking output and logging options
    # @!attribute [r] log
    #   +false+ (default when +logger+ is nil) if no logging is wanted;
    #     +true+ (default when +logger+ is set) if logging is wanted
    # @!attribute [r] logger
    #   override logging with specified Ruby Logger
    # @!attribute [r] logdev
    #   custom log device to use (when not in Rails); ignored if +logger+ is set
    #     must be filename or IO object
    # @!attribute [r] out
    #   custom IO to write output to; defaults to $stdout
    class Options
      attr_reader :log, :logger, :logdev, :out
      alias log? log
      alias out? out

      def initialize(log: nil, logger: nil, logdev: nil, out: true)
        @raw_log_argument = log
        @log = validated_log(log)
        @logger = validated_logger(logger)
        @logdev = validated_logdev(logdev)
        @out = validated_out(out)
      end

      def log=(candidate_log)
        @log = validated_log(candidate_log)
      end

      def logger=(candidate_logger)
        @logger = validated_logger(candidate_logger)
      end

      def logdev=(candidate_logdev)
        @logdev = validated_logdev(candidate_logdev)
      end

      def out=(candidate_out)
        @out = validated_out(candidate_out)
      end

      private

      attr_reader :raw_log_argument

      # @return [true, false]
      def validated_log(candidate_log)
        Internal.boolean_cast(candidate_log)
      end

      # @return [nil, Object<::Logger>]
      # @raise [InvalidLoggerOptionError] if invalid logger is specified
      def validated_logger(candidate_logger)
        return if candidate_logger.nil?
        raise InvalidLoggerOptionError unless candidate_logger.is_a?(::Logger)

        self.log = true unless log_explicit?
        candidate_logger
      end

      # @param candidate_logdev [nil, String, IO, File::NULL]
      #   logdev to use for any non-Rails :logger specified
      # @return [nil, String, IO, File::NULL]
      # @raise [InvalidLogdevOptionError] if invalid logdev is specified
      def validated_logdev(candidate_logdev)
        case candidate_logdev
        when nil, String, IO, File::NULL
          candidate_logdev
        else
          raise InvalidLogdevOptionError
        end
      end

      # @param candidate_out [nil, true, false, IO, StringIO, String, Integer]
      # @return [true, false]
      # @raise [InvalidOutOptionError] if invalid out option is specified
      def validated_out(candidate_out)
        will_output = !logging_to_stdout? && out_param_cast(candidate_out)

        self.log = true unless will_output || log_explicit?

        will_output
      end

      def log_explicit?
        !raw_log_argument.nil?
      end

      def logging_to_stdout?
        log? && ((logdev == $stdout) || (logdev == '$stdout'))
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
