require "json"

module Lba
  module Internal
    class Writer
      class << self
        def write(...) = new(...).write
      end

      def initialize(record, sink:)
        @record = record
        @sink = sink
      end

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
