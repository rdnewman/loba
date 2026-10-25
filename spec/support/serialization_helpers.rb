module SerializationHelpers
  # A bare Object.new has matching #to_s and #inspect. The instance variable
  # shows up only in #inspect, so a spec can tell which one ran.
  def object_with_distinct_inspect
    object = Object.new
    object.instance_variable_set(:@x, 1)
    object
  end

  # Has a working #to_s, but an #inspect that raises ArgumentError "boom".
  def object_whose_inspect_raises
    object = Object.new
    def object.inspect = raise(ArgumentError, "boom")
    def object.to_s = "fine as text"
    object
  end
end
