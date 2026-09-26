require "json"

module Lba
  module Internal
    # Appends one record to a sink as a line of JSON.
    class Writer
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
      # @return [void]
      def write
        if sink.respond_to?(:write)
          sink.write(line)
          sink.flush
        else
          File.open(sink, "a") { |file| file.write(line) }
        end
      end

    private

      attr_reader :record, :sink

      def line
        "#{JSON.generate(record)}\n"
      end
    end
  end
end
