module CallSiteTrackerHelpers
  # Lets CallSiteTracker.current build real trackers but captures their
  # at_exit hooks, which would otherwise fire at the suite's exit. Returns the
  # hooks in registration order so a spec can run one. Pair with reset_current.
  def stub_call_site_tracker_at_exit
    hooks = []

    allow(Lba::Internal::CallSiteTracker)
      .to receive(:new)
      .and_wrap_original do |original|
        original.call.tap do |tracker|
          allow(tracker).to receive(:at_exit) { |&hook| hooks << hook }
        end
      end

    hooks
  end
end
