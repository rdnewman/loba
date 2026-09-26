module SerializationHelpers
  # A bare Object.new has matching #to_s and #inspect. The instance variable
  # shows up only in #inspect, so a spec can tell which one ran.
  def object_with_distinct_inspect
    object = Object.new
    object.instance_variable_set(:@x, 1)
    object
  end
end
