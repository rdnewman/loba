module AllocationHelpers
  # GC allocates a few objects of its own, so it stays off while counting to
  # keep identical runs identical.
  def allocations_during
    GC.disable
    allocated_before = GC.stat[:total_allocated_objects]
    yield
    GC.stat[:total_allocated_objects] - allocated_before
  ensure
    GC.enable
  end
end
