module Lba
  module Internal
    # Decides, for one call, whether lba runs at all, where the record goes,
    # and which Logger, if any, also gets it.
    class Settings
      # Validates the logging options only when lba is enabled.
      #
      # @param log [Object] the +log:+ option given (see LogMirror.for)
      # @param logger [Logger, nil] the +logger:+ option given
      # @param sink [IO, String, Pathname, nil] the +sink:+ option given
      # @raise [InvalidLoggerOptionError] if enabled and +logger+ isn't a +Logger+
      def initialize(log: nil, logger: nil, sink: nil)
        @sink_option = sink
        return unless enabled?

        @log_mirror = LogMirror.for(log:, logger:)
      end

      # Where the record goes, built on first use. Its sink is resolved then
      # (see SinkResolver#resolve), which can create the default sink's
      # directory. Never built when disabled, so a production environment
      # never touches the filesystem.
      #
      # @return [Destination, nil] the sink, and the LogMirror if logging;
      #   +nil+ when disabled
      def destination
        return if disabled?

        @destination ||= Destination.new(sink: SinkResolver.resolve(sink: sink_option), log_mirror:)
      end

      # @return [Boolean] +false+ in a production environment (see
      #   Platform::Environment.production?); otherwise +true+
      def enabled? = !Internal::Platform::Environment.production?

      # @return [Boolean] +true+ in a production environment (see
      #   Platform::Environment.production?); otherwise +false+
      def disabled? = !enabled?

    private

      attr_reader :log_mirror, :sink_option
    end
  end
end
