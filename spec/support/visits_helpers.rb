module VisitsHelpers
  # Captures Run::Visits' at_exit hooks (see AtExitHelpers).
  def stub_visits_at_exit = capture_at_exit_hooks(Lba::Internal::Run::Visits)
end
