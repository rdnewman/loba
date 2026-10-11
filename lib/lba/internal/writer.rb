require "json"

module Lba
  module Internal
    # Appends one record to a sink as a line of JSON.
    class Writer
      APPEND_FLAGS = File::WRONLY | File::APPEND | File::CREAT
      # Records hold unredacted values, so a file Writer creates is readable
      # only by its owner. An existing file keeps its mode.
      NEW_FILE_MODE = 0o600
      private_constant :APPEND_FLAGS, :NEW_FILE_MODE

      class << self
        # Writes the record; shorthand for +new(...).write+.
        #
        # @return (see #write)
        def write(...) = new(...).write
      end

      # @param record [Hash] the record to write
      # @param sink [IO, String] an IO, or a file path to append to
      def initialize(record, sink:)
        @record = record
        @sink = sink
      end

      # Writes the line, flushing an IO so the record isn't held in a buffer.
      #
      # If the sink can't be written (a full disk, a read-only file, a closed
      # IO), the record is skipped and WriteFailures counts it, so tracing
      # never breaks the traced code. The next record that is written to the
      # sink notes what was missed, in +:unwritten+. Any other error is lba's
      # own bug, and raises.
      #
      # @return [void]
      def write
        gap = WriteFailures.existing&.unwritten(sink)
        append(with_gap(gap))
        WriteFailures.existing.forget_unwritten(sink) if gap
      rescue SystemCallError, IOError => e
        WriteFailures.current.report(sink:, error: e, seq: record[:seq])
      end

    private

      attr_reader :record, :sink

      def with_gap(gap)
        if gap
          record.merge(unwritten: gap)
        else
          record
        end
      end

      def append(fields)
        line = "#{JSON.generate(fields)}\n"

        if sink.respond_to?(:write)
          sink.write(line)
          sink.flush
        else
          File.open(sink, APPEND_FLAGS, NEW_FILE_MODE) { |file| file.write(line) }
        end
      end
    end
  end
end
