module DestinationHelpers
  # Where a record goes, for specs that pass a sink and maybe a logger.
  def destination_to(sink, logger: nil)
    log_mirror = (Loba::Internal::Destination::LogMirror.new(logger:) if logger)
    Loba::Internal::Destination.new(sink: Loba::Internal::Destination::Sink.new(sink), log_mirror:)
  end

  # What the block writes to $stdout and $stderr when a symlink to +target+ is
  # already at the run's file. A forked child starts a real run of its own in
  # the target's directory, so nothing from the block's public call down to the
  # filesystem is stubbed.
  def output_with_symlink_at_run_file(target)
    in_forked_child do
      Dir.chdir(File.dirname(target))
      ENV.delete("LOBA_SINK")
      $stdout = StringIO.new
      $stderr = StringIO.new
      plant_symlink_at_run_file(target)

      yield

      { stdout: $stdout.string, stderr: $stderr.string }
    end
  end

private

  def plant_symlink_at_run_file(target)
    runs_dir = File.join(Dir.pwd, ".loba", "runs")
    FileUtils.mkdir_p(runs_dir)
    File.symlink(target, File.join(runs_dir, "#{Loba::Internal::Run.current.id}.jsonl"))
  end
end
