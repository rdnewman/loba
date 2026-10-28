module RunHelpers
  # The exit hooks registered by runs created during the example, in
  # registration order (see AtExitHelpers). spec_helper captures them for
  # every example.
  attr_reader :run_exit_hooks
end
