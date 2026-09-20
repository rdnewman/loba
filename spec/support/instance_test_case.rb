# Base harness for scenarios where the {Lba::Internal::CallerBinding} subject is
# exercised from within a genuine instance method call, so +self+ at the
# reflection point is a real instance, not the class itself.
class InstanceTestCase
  class << self
    alias instance_with new # for readability only
    alias with new # for readability only
  end

  # @param subject [Lba::Internal::CallerBinding] the subject being exercised
  def initialize(subject)
    @subject = subject
  end

  # @return [String] whatever +subject.class_name+ reports for this instance
  def class_name = subject.class_name

  # @return [Symbol] whatever +subject.method_type+ reports for this instance
  def method_type = subject.method_type

  # @return [String] whatever +subject.source_line+ reports for this instance
  def source_line = subject.source_line

  # @return [String] whatever +subject.file+ reports for this instance
  def file = subject.file

  # @return [Integer] whatever +subject.line+ reports for this instance
  def line = subject.line

private

  attr_reader :subject
end
