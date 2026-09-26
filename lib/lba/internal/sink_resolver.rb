require "fileutils"

module Lba
  module Internal
    # Decides where a record is written.
    class SinkResolver
      class << self
        # Decides the sink; shorthand for +new(...).resolve+.
        #
        # @return (see #resolve)
        def resolve(...) = new(...).resolve
      end

      # @param sink [IO, String, nil] an explicit sink, if one was given
      # @param run [Run] the run whose file is the default sink
      def initialize(sink: nil, run: Run.current)
        @sink = sink
        @run = run
      end

      # In order: an IO given as +sink+; a path given as +sink+; the +LBA_SINK+
      # environment variable; the run's file (under +tmp/lba/runs/+ in Rails,
      # otherwise +.lba/runs/+ in the current directory). Falls back to
      # +$stdout+ if the chosen path's directory can't be created or written.
      #
      # @return [IO, String] an IO, or a file path to append to
      def resolve
        return sink if sink.respond_to?(:write)

        candidate = sink || ENV["LBA_SINK"] || default_path

        if ensure_writable(candidate)
          candidate
        else
          $stdout
        end
      end

    private

      attr_reader :sink, :run

      def default_path
        if within_rails?
          File.join(::Rails.root, "tmp", "lba", "runs", "#{run.id}.jsonl")
        else
          File.join(Dir.pwd, ".lba", "runs", "#{run.id}.jsonl")
        end
      end

      def within_rails?
        defined?(::Rails) && ::Rails.respond_to?(:root)
      end

      def ensure_writable(path)
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir)
        File.writable?(dir)
      rescue SystemCallError
        false
      end
    end
  end
end
