module Lba
  module Internal
    # Decides, for one call, whether lba runs at all and which Logger, if any,
    # also gets the record.
    class Settings
      # Validates the logging options only when lba is enabled.
      #
      # @param log [Object] the +log:+ option given (see LogMirror.for)
      # @param logger [Logger, nil] the +logger:+ option given
      # @raise [InvalidLoggerOptionError] if enabled and +logger+ isn't a +Logger+
      def initialize(log: nil, logger: nil)
        return unless enabled?

        @log_mirror = LogMirror.for(log:, logger:)
      end

      def log? = !log_mirror.nil?

      # @return [Logger, nil] the Logger to also write to, or +nil+ for none
      def logger = log_mirror&.logger

      # @return [Boolean] +false+ inside a Rails production environment;
      #   otherwise +true+
      def enabled? = !Internal::Platform::WithinRails.production?

      # @return [Boolean] the opposite of #enabled?
      def disabled? = !enabled?

    private

      attr_reader :log_mirror
    end
  end
end
