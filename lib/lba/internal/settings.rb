module Lba
  module Internal
    # Decides, for one call, whether lba runs at all, where the record goes,
    # and which Logger, if any, also gets it.
    class Settings
      # Validates the logging options only when lba is enabled.
      #
      # @param log [Object] the +log:+ option given (see LogMirror.for)
      # @param logger [Logger, nil] the +logger:+ option given
      # @param sink [IO, String, nil] the +sink:+ option given
      # @raise [InvalidLoggerOptionError] if enabled and +logger+ isn't a +Logger+
      def initialize(log: nil, logger: nil, sink: nil)
        @sink_option = sink
        return unless enabled?

        @log_mirror = LogMirror.for(log:, logger:)
      end

      # @return [Logger, nil] the Logger to also write to, or +nil+ for none
      def logger = log_mirror&.logger

      # Where the record goes, resolved on first use (see SinkResolver#resolve),
      # which can create the default sink's directory. Never resolved when
      # disabled, so a Rails production environment never touches the
      # filesystem.
      #
      # @return [IO, String, nil] an IO, or a file path to append to; +nil+
      #   when disabled
      def sink
        return if disabled?

        @sink ||= SinkResolver.resolve(sink: sink_option)
      end

      # @return [Boolean] +false+ inside a Rails production environment;
      #   otherwise +true+
      def enabled? = !Internal::Platform::WithinRails.production?

      # @return [Boolean] +true+ inside a Rails production environment;
      #   otherwise +false+
      def disabled? = !enabled?

    private

      attr_reader :log_mirror, :sink_option
    end
  end
end
