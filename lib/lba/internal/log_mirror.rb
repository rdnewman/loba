module Lba
  module Internal
    class LogMirror
      attr_reader :logger

      FALSE_VALUES = [
        false, 0, nil, "",
        "0", :"0",
        "f", :f,
        "F", :F,
        "false", :false, # rubocop:disable Lint/BooleanSymbol
        "FALSE", :FALSE,
        "off", :off,
        "OFF", :OFF
      ].to_set.freeze
      private_constant :FALSE_VALUES

      class << self
        def for(log:, logger:)
          return unless wanted?(log:, logger:)

          new(logger:)
        end

      private

        def wanted?(log:, logger:)
          return boolean_cast(log) unless log.nil?

          !logger.nil?
        end

        # rubocop:disable-next Naming/PredicateMethod -- a cast/conversion, not a predicate
        def boolean_cast(value)
          !FALSE_VALUES.include?(value)
        end
      end

      def initialize(logger: nil)
        @logger = validated_logger(logger)
        @logger ||= default_logger
      end

    private

      def validated_logger(candidate_logger)
        return if candidate_logger.nil?
        raise InvalidLoggerOptionError if invalid_logger?(candidate_logger)

        candidate_logger
      end

      def real_logger?(candidate_logger)
        defined?(::Logger) && candidate_logger.is_a?(::Logger)
      end

      def invalid_logger?(candidate_logger) = !real_logger?(candidate_logger)

      def default_logger
        ::Rails.logger if Internal::Platform::WithinRails.logger?
      end
    end
  end
end
