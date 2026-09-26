# rubocop:disable Style/GuardClause, Style/IfUnlessModifier

# Exercises {Lba::Internal::CallerBinding} from a class method, so +self+ is
# the class. Never instantiated; an instance would defeat the scenario.
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

    # @return [String] whatever +subject.class_name+ reports for this class
    def class_name = subject.class_name

    # Clears the configured subject. It's class state that outlives the
    # example, so call this in an +after+ hook wherever +as_class_using+ is used.
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
