module CallSiteTrackerHelpers
  # Captures CallSiteTracker's at_exit hooks (see AtExitHelpers).
  def stub_call_site_tracker_at_exit = capture_at_exit_hooks(Lba::Internal::CallSiteTracker)
end
