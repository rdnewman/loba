# rubocop:disable Style/GuardClause, Style/IfUnlessModifier

# Base harness for scenarios where the {Lba::Internal::CallerBinding} subject is
# exercised from within a genuine class method call, so +self+ at the
# reflection point is the class itself -- never instantiated, since a real
# instance would defeat the scenario this harness exists to represent.
class ClassTestCase
  class << self
    # Configures this class to use +subject+ and returns the class itself
    # (never a new instance -- see the class comment for why).
    #
    # @param subject [Lba::Internal::CallerBinding] the subject being exercised
    # @return [Class] this class, now aware of +subject+
    def as_class_using(subject)
      self.subject = subject
      self
    end
    alias as_a_class_using as_class_using

    # @return [Symbol] whatever +subject.method_type+ reports for this class
    def method_type = subject.method_type

    # Clears the subject this class was configured with. Unlike an
    # InstanceTestCase, whose subject dies with its instance, this class's
    # subject is real persistent class state that outlives any one example --
    # call this in an +after+ hook wherever +as_class_using+ is used, so it
    # doesn't leak into whatever example runs next.
    def reset_subject
      if instance_variable_defined?(:@subject)
        remove_instance_variable(:@subject)
      end
    end

  private

    attr_accessor :subject
  end
end

# rubocop:enable Style/GuardClause, Style/IfUnlessModifier
