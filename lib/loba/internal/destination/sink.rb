require "fileutils"

module Loba
  module Internal
    class Destination
      # The IO or file a destination's records are appended to, one line each.
      class Sink
        APPEND_FLAGS = File::WRONLY | File::APPEND | File::CREAT
        # Records hold unredacted values, so a file a Sink creates is readable
        # only by its owner. An existing file keeps its mode.
        NEW_FILE_MODE = 0o600
        RUN_DIR_MODE = 0o700
        private_constant :APPEND_FLAGS, :NEW_FILE_MODE, :RUN_DIR_MODE

        class << self
          # The sink for the +sink:+ option given. In order: an IO given; a
          # path given; the +LOBA_SINK+ environment variable; the run's file
          # (under +tmp/loba/runs/+ in Rails, otherwise +.loba/runs/+ in the
          # directory the run started in). A relative path given or in
          # +LOBA_SINK+ is taken from the directory the run started in (see
          # Run#start_dir), not the current one.
          #
          # Falls back to +$stdout+ if the chosen path's directory can't be
          # created or written, or if something other than this run already put
          # a file at the run's path (see Run#claim_file), and has the run
          # report it (see Run#report_fallback).
          #
          # Directories created for the run's file are accessible only by their
          # owner, since records hold unredacted values.
          #
          # @param option [IO, String, Pathname, nil] the +sink:+ option given
          # @return [Sink]
          def for(option)
            return new(option) if io?(option)

            given = given_path(option)
            for_path(given || default_path, given:)
          end

        private

          def for_path(path, given:)
            reason = refusal(path, given:)

            if reason
              Run.current.report_fallback(path:, reason:)
              new($stdout)
            else
              new(path)
            end
          end

          # An absolute copy, so neither a later chdir nor a change to the
          # caller's String changes which file the sink is.
          def given_path(option)
            path = explicit_path(option) || env_path
            File.absolute_path(path, Run.current.start_dir) if path
          end

          # Why the path can't be used, or +nil+ if it can.
          def refusal(path, given:)
            if given
              directory_refusal(path)
            else
              directory_refusal(path, mode: RUN_DIR_MODE) || claim_refusal(path)
            end
          end

          # A Pathname responds to #write too, but by rewriting its file, so it's
          # treated as the path it names.
          def io?(option)
            option.respond_to?(:write) && !pathname?(option)
          end

          def pathname?(option)
            defined?(::Pathname) && option.is_a?(::Pathname)
          end

          def explicit_path(option)
            if pathname?(option)
              option.to_s
            else
              option
            end
          end

          def env_path
            path = ENV.fetch("LOBA_SINK", nil)
            path unless path.to_s.empty?
          end

          def default_path
            rails_root = Platform::WithinRails.root
            run = Run.current

            if rails_root
              File.join(rails_root, "tmp", "loba", "runs", "#{run.id}.jsonl")
            else
              File.join(run.start_dir, ".loba", "runs", "#{run.id}.jsonl")
            end
          end

          def directory_refusal(path, **)
            dir = File.dirname(path)
            FileUtils.mkdir_p(dir, **)
            "its directory isn't writable" unless File.writable?(dir)
          rescue SystemCallError => e
            "#{e.class}: #{e.message}"
          end

          def claim_refusal(path)
            "this run couldn't create it as a new file" unless Run.current.claim_file(path)
          end
        end

        # @param target [IO, String] an IO, or a file path to append to
        def initialize(target)
          @target = target
        end

        # Writes the line to the target, flushing an IO so the line isn't held
        # in a buffer. Meant for Run::Recorder only, which notes on a sink's
        # next record any records the sink missed.
        #
        # @param line [String] a record's line, newline included
        # @return [void]
        # @raise [SystemCallError, IOError] if the target can't be written (a
        #   full disk, a read-only file, a closed IO)
        def append(line)
          if target.respond_to?(:write)
            target.write(line)
            target.flush
          else
            File.open(target, APPEND_FLAGS, NEW_FILE_MODE) { |file| file.write(line) }
          end
        end

        # Whether +other+ is the same sink: a Sink on an equal path or on the
        # same IO object. Each call builds its own Sink, so this is how a sink
        # is recognized from one call to the next.
        #
        # @param other [Object]
        # @return [Boolean]
        def eql?(other)
          other.instance_of?(Sink) && target.eql?(other.target)
        end
        alias == eql?

        # @return [Integer] equal for sinks that are #eql?
        def hash
          [Sink, target].hash
        end

        # How loba's messages name the sink: its target as +inspect+ shows it,
        # so a path keeps its quotes.
        #
        # @return [String] e.g. +"\"a.jsonl\""+
        def to_s
          target.inspect
        end

      protected

        attr_reader :target
      end
    end
  end
end
