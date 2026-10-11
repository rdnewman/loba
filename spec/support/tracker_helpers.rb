module TrackerHelpers
  # Captures Tracker's at_exit hooks (see AtExitHelpers).
  def stub_tracker_at_exit = capture_at_exit_hooks(Lba::Internal::Tracker)
end
