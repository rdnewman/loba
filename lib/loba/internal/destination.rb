require_relative "destination/log_mirror"
require_relative "destination/sink"

module Loba
  module Internal
    # Where a call site's records go: a sink, and a LogMirror when logging.
    class Destination
      # Where one call's records go, from the options it was given. A misused
      # +logger:+ fails before the default sink's directory is created.
      #
      # @param sink [IO, String, Pathname, nil] the +sink:+ option given
      # @param log [Object] the +log:+ option given (see LogMirror.for)
      # @param logger [Logger, nil] the +logger:+ option given
      # @return [Destination]
      # @raise [InvalidLoggerOptionError] if logging is wanted and +logger+ is
      #   neither +nil+ nor a +Logger+
      def self.for(sink:, log:, logger:)
        # Built before the call to new, not as its argument: keyword arguments
        # run in order, and resolving the sink can create directories, so the
        # logger has to be checked first.
        log_mirror = LogMirror.for(log:, logger:)
        new(sink: Sink.for(sink), log_mirror:)
      end

      # @param sink [Sink] where records are appended
      # @param log_mirror [LogMirror, nil] where records are mirrored; +nil+ if
      #   not logging
      def initialize(sink:, log_mirror:)
        @sink = sink
        @log_mirror = log_mirror
      end

      # Writes the record to the sink, through the run's Recorder, and to the
      # log mirror if there is one. The mirror gets the record as given: a gap
      # the sink noted on it is the sink's, not the log's.
      #
      # @param fields [Hash] the record
      # @return [void]
      def write(fields)
        recorder.write(fields, to: sink)
        log_mirror&.write(fields)
      end

    private

      attr_reader :sink, :log_mirror

      def recorder = Run.current.recorder
    end
  end
end
