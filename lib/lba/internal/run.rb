require "securerandom"

module Lba
  module Internal
    # One process's run: every record it writes carries the run's id, and its
    # records share one sink file. A forked child is a run of its own.
    class Run
      # Fails if anything, even a symlink, is already at the path.
      CREATE_FLAGS = File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW
      private_constant :CREATE_FLAGS

      class << self
        # This process's run, created on first use. Creating it registers the
        # run's +at_exit+ hook, which writes the count of calls skipped at any
        # capped site, then summarizes records that couldn't be written.
        #
        # A forked child inherits this memo; the pid check gives it its own run
        # and file.
        #
        # @return [Run]
        def current
          if @current&.pid == Process.pid
            return @current
          end

          @current = new.tap do |run|
            run.send(:register_at_exit)
          end
        end
      end

      # @return [String] the run's id: a UTC timestamp, the process id, and eight
      #   random hex digits, e.g. +"20260926T210626Z-894825-b10f3e7a"+
      attr_reader :id

      # @return [Integer] the id of the process that started the run
      attr_reader :pid

      # @return [Visits] the run's visits to call sites
      attr_reader :visits

      # @return [Delivery] the run's writing of records to their sinks
      attr_reader :delivery

      # Starts a run for the current process.
      def initialize
        @pid = Process.pid
        @id = generate_id
        @claimed_paths = []
        @visits = Visits.new
        @delivery = Delivery.new
      end

      # Claims a file for this run's records: creates it, readable and writable
      # only by its owner, the first time it's claimed.
      #
      # A file or symlink already at the path wasn't made by this run (the
      # random part of the id makes the path hard to guess ahead of time), so
      # the path is refused rather than appended to.
      #
      # @param path [String] where the run's file goes
      # @return [Boolean] whether this run created the file at +path+
      def claim_file(path)
        claimed_paths.include?(path) || claim(path)
      end

    private

      attr_reader :claimed_paths

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
      # that can't be written is counted in the summary rather than lost.
      def shut_down
        visits.flush
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
