require "fileutils"

module Lba
  module Internal
    class SinkResolver
      class << self
        def resolve(...) = new(...).resolve
      end

      def initialize(sink: nil, run: Run.current)
        @sink = sink
        @run = run
      end

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
