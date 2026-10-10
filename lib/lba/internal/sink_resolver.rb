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

      # @param sink [IO, String, Pathname, nil] an explicit sink, if one was given
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
        return sink if io?

        candidate = explicit_path || env_path || default_path

        if ensure_writable(candidate)
          candidate
        else
          $stdout
        end
      end

    private

      attr_reader :sink, :run

      # A Pathname responds to #write too, but by rewriting its file, so it's
      # treated as the path it names.
      def io?
        sink.respond_to?(:write) && !pathname?
      end

      def pathname?
        defined?(::Pathname) && sink.is_a?(::Pathname)
      end

      def explicit_path
        if pathname?
          sink.to_s
        else
          sink
        end
      end

      def env_path
        path = ENV.fetch("LBA_SINK", nil)
        path unless path.to_s.empty?
      end

      def default_path
        if within_rails?
          File.join(::Rails.root, "tmp", "lba", "runs", "#{run.id}.jsonl")
        else
          File.join(Dir.pwd, ".lba", "runs", "#{run.id}.jsonl")
        end
      end

      def within_rails?
        defined?(::Rails) && ::Rails.respond_to?(:root) && ::Rails.root
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
