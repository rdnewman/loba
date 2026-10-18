require "securerandom"
require_relative "run/lock"
require_relative "run/visits"
require_relative "run/delivery"

module Lba
  module Internal
    # One process's run: every record it writes carries the run's id, and its
    # records share one sink file. A forked child is a run of its own.
    class Run
      # Fails if anything, even a symlink, is already at the path.
      CREATE_FLAGS = File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW

      # Lets one thread at a time create the process's run.
      CREATION_LOCK = Lock.new
      private_constant :CREATE_FLAGS, :CREATION_LOCK

      class << self
        # This process's run, created on first use. Creating it registers the
        # run's +at_exit+ hook, which writes the count of calls skipped at any
        # capped site, then summarizes records that couldn't be written.
        #
        # A forked child inherits this memo; the pid check gives it its own run
        # and file. Threads asking at once share one run: only creating it
        # takes a lock, and the check is repeated inside it.
        #
        # @return [Run]
        def current
          if current_in_this_process?
            return @current
          end

          CREATION_LOCK.synchronize { @current = current_or_new }
        end

      private

        def current_in_this_process?
          @current&.pid == Process.pid
        end

        def current_or_new
          if current_in_this_process?
            @current
          else
            new.tap { |run| run.send(:register_at_exit) }
          end
        end
      end

      # @return [String] the run's id: a UTC timestamp, the process id, and eight
      #   random hex digits, e.g. +"20260926T210626Z-894825-b10f3e7a"+
      attr_reader :id

      # @return [Integer] the id of the process that started the run
      attr_reader :pid

      # @return [String] the working directory when the run started, which
      #   relative sink paths are taken from, so a later chdir doesn't send the
      #   rest of the run's records to another file
      attr_reader :start_dir

      # @return [Visits] the run's visits to call sites
      attr_reader :visits

      # @return [Delivery] the run's writing of records to their sinks
      attr_reader :delivery

      # Starts a run for the current process.
      def initialize
        @pid = Process.pid
        @id = generate_id
        @start_dir = Dir.pwd
        @claimed_paths = []
        @claim_lock = Lock.new
        @fallback_reported = false
        @visits = Visits.new
        @delivery = Delivery.new
      end

      # Claims a file for this run's records: creates it, readable and writable
      # only by its owner, the first time it's claimed.
      #
      # A file or symlink already at the path wasn't made by this run (the
      # random part of the id makes the path hard to guess ahead of time), so
      # the path is refused rather than appended to. Threads claiming one path
      # at once all get it.
      #
      # @param path [String] where the run's file goes
      # @return [Boolean] whether this run created the file at +path+
      def claim_file(path)
        claim_lock.synchronize do
          claimed_paths.include?(path) || claim(path)
        end
      end

      # Warns on $stderr, the first time in the process, that records meant for
      # +path+ go to $stdout instead, so an empty file isn't mistaken for code
      # that never ran.
      #
      # @param path [String] the path that couldn't be used
      # @param reason [String] why not, e.g. +"its directory isn't writable"+
      # @return [void]
      def report_fallback(path:, reason:)
        return if @fallback_reported

        @fallback_reported = true
        warn "lba: can't use #{path.inspect} (#{reason}); " \
             "writing records to $stdout instead; " \
             "later fallbacks in this process won't be reported"
      end

    private

      attr_reader :claimed_paths, :claim_lock

      # Forked children inherit this hook; the pid check keeps them from
      # re-flushing the parent's capped sites or repeating its summary.
      def register_at_exit
        at_exit do
          if pid == Process.pid
            shut_down
          end
        end
      end

      # Summarizes write failures only after flushing, so a skipped-call record
      # that can't be written is counted in the summary rather than lost; and
      # even if flushing raises, so the summary isn't lost either.
      def shut_down
        visits.flush
      ensure
        delivery.summarize
      end

      def claim(path)
        create_exclusively(path)
        claimed_paths << path
        true
      rescue SystemCallError
        false
      end

      # Fails if anything is already at the path, a symlink included.
      def create_exclusively(path)
        File.write(path, "", flags: CREATE_FLAGS, perm: 0o600)
      end

      def generate_id
        timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
        "#{timestamp}-#{pid}-#{SecureRandom.hex(4)}"
      end
    end
  end
end
