module Lba
  # rubocop:disable-next Metrics/ParameterLists -- matches Internal::Value's public kwarg surface
  def self.val(argument, label: nil, inspect: true, log: nil, logger: nil, sink: nil)
    Internal::Value.record(argument, label:, inspect:, log:, logger:, sink:)
  end
end
