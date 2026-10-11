module Lba
  module Internal
    # A call site: one record type at one file and line. Sites with the same
    # type, file, and line are equal, so a site works as a Hash key.
    #
    # @!attribute [r] type
    #   @return [String] the kind of record, e.g. +"val"+
    # @!attribute [r] file
    #   @return [String] the calling file
    # @!attribute [r] line
    #   @return [Integer] the calling line
    Site = Data.define(:type, :file, :line)
  end
end
