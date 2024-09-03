module LobaSpecSupport
  module MockedRails
    def mock_rails(production:, logger: nil)
      mock_rails = double # impossible to define verifying double w/o Rails already defined
      allow(mock_rails).to receive_messages(env: double, logger: logger)
      allow(mock_rails.env).to receive(:production?).and_return(production)

      mock_rails
    end
    module_function :mock_rails

    def mock_rails_logger(present:, output:)
      mock_rails_logger_class = Class.new(Logger) { def present?; end }
      mock_logger = mock_rails_logger_class.new(output)
      allow(mock_logger).to receive(:present?).and_return(!!present)
      allow(mock_logger).to receive(:debug).and_call_original

      mock_logger
    end
    module_function :mock_rails_logger
  end
end
