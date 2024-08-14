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

      def initialize(log: false, logger: nil, logdev: nil, out: nil)
        @log = validated_log(log)
        @logger = validated_logger(logger)
        @logdev = validated_logdev(logdev)
        @out = validated_out(out)
      end

      def log=(candidate_log)
        validated_log(candidate_log)
      end

      def logger=(candidate_logger)
        validated_logger(candidate_logger)
      end

      def logdev=(candidate_logdev)
        validated_logdev(candidate_logdev)
      end

      def out=(candidate_out)
        validated_out(candidate_out)
      end

      def to_h
        { log: log, logger: logger, logdev: logdev, out: out }
      end

      private

      # @return [true, false]
      def validated_log(candidate_log)
        Internal.boolean_cast(candidate_log)
      end

      # @return [nil, Object<::Logger>]
      def validated_logger(candidate_logger)
        return unless candidate_logger.is_a?(::Logger)

        candidate_logger
      end

      # return [nil, String, IO]
      def validated_logdev(candidate_logdev)
        return unless candidate_logdev.is_a?(String) || candidate_logdev.is_a?(IO)

        candidate_logdev
      end

      # return [nil, IO]
      def validated_out(candidate_out)
        return unless candidate_out
        return unless candidate_out.is_a?(IO)
        return if candidate_out == $stdout

        candidate_out
      end
    end
  end
end
