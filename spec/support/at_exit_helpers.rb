module AtExitHelpers
  # Lets klass build real instances but captures the at_exit hooks they
  # register, which would otherwise fire at the suite's exit. Returns the hooks
  # in registration order so a spec can run one. Pass the same into: array for
  # several classes to keep their hooks in one registration order, which
  # reverse_each then runs as Ruby does at exit. Pair with reset_current.
  def capture_at_exit_hooks(klass, into: [])
    hooks = into

    allow(klass).to receive(:new).and_wrap_original do |original|
      original.call.tap do |instance|
        allow(instance).to receive(:at_exit) { |&hook| hooks << hook }
      end
    end

    hooks
  end
end
