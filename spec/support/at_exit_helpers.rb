module AtExitHelpers
  # Lets klass build real instances but captures the at_exit hooks they
  # register, which would otherwise fire at the suite's exit. Returns the hooks
  # in registration order so a spec can run one. Pair with reset_current.
  #
  # at_exit is stubbed before #initialize runs, so a hook registered while the
  # instance is built is captured too, rather than registered for real.
  def capture_at_exit_hooks(klass)
    hooks = []

    allow(klass).to receive(:new) do
      klass.allocate.tap do |instance|
        allow(instance).to receive(:at_exit) { |&hook| hooks << hook }
        instance.send(:initialize)
      end
    end

    hooks
  end
end
