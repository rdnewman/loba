module MemoizedCurrentHelpers
  # Run, Run::Visits, and Run::WriteFailures memoize into a class-level
  # @current. Any other
  # class-level state would survive this reset, so it fails loudly instead.
  def reset_current(klass)
    unexpected = klass.instance_variables - [:@current]

    if unexpected.any?
      raise "#{klass} holds class-level state besides @current: #{unexpected.inspect}"
    end

    klass.instance_variable_set(:@current, nil)
  end
end
