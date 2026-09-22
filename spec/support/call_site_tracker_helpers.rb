module CallSiteTrackerHelpers
  # Stubbing out Kernel#at_exit (rather than letting it really register) keeps
  # a stray hook from surviving into the rest of the test suite and firing
  # against stale doubles when the real rspec process exits.
  def capture_at_exit_hooks(on:)
    hooks = []
    allow(on).to receive(:at_exit) { |&block| hooks << block }
    hooks
  end

  # Makes Lba::Internal::CallSiteTracker.current return a real, fully-working
  # tracker instance -- real seq/site_seq/cap behavior -- without registering
  # a real at_exit hook against the actual test process. Caller is
  # responsible for resetting @current back to nil afterward (an `after`
  # hook), since this still memoizes into the real class-level singleton.
  def safe_call_site_tracker_current
    tracker = Lba::Internal::CallSiteTracker.new
    capture_at_exit_hooks(on: tracker)
    allow(Lba::Internal::CallSiteTracker).to receive(:new).and_return(tracker)
    tracker
  end
end
