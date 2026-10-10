module Lba
  module Internal
    module Records
      # The fields that describe the calling frame, shared by value and
      # timestamp records.
      module Caller
        # @param caller_binding [CallerBinding] the calling frame
        # @return [Hash{Symbol => Object}] +:file+, +:line+, +:class_name+,
        #   +:method_name+, and +:method_type+, in that order
        def self.fields(caller_binding)
          {
            file: caller_binding.file,
            line: caller_binding.line,
            class_name: caller_binding.class_name,
            method_name: caller_binding.method_name,
            method_type: caller_binding.method_type
          }
        end
      end
    end
  end
end
