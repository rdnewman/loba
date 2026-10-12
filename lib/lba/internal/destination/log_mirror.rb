require "json"

module Lba
  module Internal
    class Destination
      # Decides whether a record is also written to a Logger, and which one, and
      # writes it there.
      class LogMirror
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
          # A mirror when logging is wanted, or +nil+ when it isn't.
          #
          # @param log [Object] +nil+ to decide from +logger+; otherwise read as a
          #   switch, where +false+, +0+, +nil+, +""+, and +"0"+, +"f"+, +"false"+,
          #   +"off"+ (as Strings or Symbols, lower or upper case) mean off
          # @param logger [Logger, nil] a Logger to write to; with +log: nil+, giving
          #   one turns logging on
          # @return [LogMirror, nil]
          # @raise [InvalidLoggerOptionError] if logging is wanted and +logger+ is
          #   neither +nil+ nor a +Logger+
          def for(log:, logger:)
            return unless wanted?(log:, logger:)

            new(logger:)
          end

        private

          def wanted?(log:, logger:)
            return boolean_cast(log) unless log.nil?

            !logger.nil?
          end

          # A cast, not a predicate: it turns a +log:+ value into true or false.
          def boolean_cast(value) # rubocop:disable Naming/PredicateMethod
            !FALSE_VALUES.include?(value)
          end
        end

        # @param logger [Logger, nil] a Logger to write to; +nil+ to use
        #   +Rails.logger+, if any
        # @raise [InvalidLoggerOptionError] if +logger+ is neither +nil+ nor a
        #   +Logger+
        def initialize(logger: nil)
          @logger = validated_logger(logger)
          @logger ||= default_logger
        end

        # Writes the record to the Logger as one JSON line, at +debug+ level.
        # Writes nothing when there's no Logger: outside Rails, with none given.
        #
        # @param fields [Hash] the record
        # @return [void]
        def write(fields)
          logger&.debug(JSON.generate(fields))
        end

      private

        # The given Logger, else +Rails.logger+ if Rails has one; +nil+ outside
        # Rails when none was given.
        attr_reader :logger

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
end
