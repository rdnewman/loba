require "fileutils"
require "json"

module Lba
  module Internal
    class Destination
      # The IO or file a destination appends records to, one line of JSON each.
      class Sink
        APPEND_FLAGS = File::WRONLY | File::APPEND | File::CREAT
        # Records hold unredacted values, so a file a Sink creates is readable
        # only by its owner. An existing file keeps its mode.
        NEW_FILE_MODE = 0o600
        RUN_DIR_MODE = 0o700
        private_constant :APPEND_FLAGS, :NEW_FILE_MODE, :RUN_DIR_MODE

        class << self
          # The sink for the +sink:+ option given. In order: an IO given; a
          # path given; the +LBA_SINK+ environment variable; the run's file
          # (under +tmp/lba/runs/+ in Rails, otherwise +.lba/runs/+ in the
          # current directory). Falls back to +$stdout+ if the chosen path's
          # directory can't be created or written, or if something other than
          # this run already put a file at the run's path (see Run#claim_file).
          #
          # Directories created for the run's file are accessible only by their
          # owner, since records hold unredacted values.
          #
          # @param option [IO, String, Pathname, nil] the +sink:+ option given
          # @return [Sink]
          def for(option)
            return new(option) if io?(option)

            path = given_path(option) || default_path

            if usable?(path, given: given_path(option))
              new(path)
            else
              new($stdout)
            end
          end

        private

          def given_path(option)
            explicit_path(option) || env_path
          end

          def usable?(path, given:)
            if given
              ensure_writable(path)
            else
              ensure_writable(path, mode: RUN_DIR_MODE) && Run.current.claim_file(path)
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
            path = ENV.fetch("LBA_SINK", nil)
            path unless path.to_s.empty?
          end

          def default_path
            if within_rails?
              File.join(::Rails.root, "tmp", "lba", "runs", "#{Run.current.id}.jsonl")
            else
              File.join(Dir.pwd, ".lba", "runs", "#{Run.current.id}.jsonl")
            end
          end

          def within_rails?
            defined?(::Rails) && ::Rails.respond_to?(:root) && ::Rails.root
          end

          def ensure_writable(path, **)
            dir = File.dirname(path)
            FileUtils.mkdir_p(dir, **)
            File.writable?(dir)
          rescue SystemCallError
            false
          end
        end

        # @param target [IO, String] an IO, or a file path to append to
        def initialize(target)
          @target = target
        end

        # Writes the record as a line, flushing an IO so the record isn't held
        # in a buffer.
        #
        # If the target can't be written (a full disk, a read-only file, a
        # closed IO), the record is skipped and Run::WriteFailures counts it,
        # so tracing never breaks the traced code. The next record written to
        # the same target notes what was missed, in +:unwritten+. Any other
        # error is lba's own bug, and raises.
        #
        # @param fields [Hash] the record
        # @return [void]
        def write(fields)
          write_failures = Run.current.write_failures
          gap = write_failures.unwritten(target)

          append(with_gap(fields, gap))

          write_failures.forget_unwritten(target) if gap
        rescue SystemCallError, IOError => e
          write_failures.report(sink: target, error: e, seq: fields[:seq])
        end

      private

        attr_reader :target

        def with_gap(fields, gap)
          if gap
            gap.noted_on(fields)
          else
            fields
          end
        end

        def append(fields)
          line = "#{JSON.generate(fields)}\n"

          if target.respond_to?(:write)
            target.write(line)
            target.flush
          else
            File.open(target, APPEND_FLAGS, NEW_FILE_MODE) { |file| file.write(line) }
          end
        end
      end
    end
  end
end
