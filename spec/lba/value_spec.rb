require "json"
require "stringio"

class LbaValIntegrationTestCase
  def call_val(**)
    lba_local_var = "traced value" # rubocop:disable Lint/UselessAssignment -- read via Lba.val's eval
    Lba.val(:lba_local_var, **)
  end

  LINE_OF_VAL_CALL = instance_method(:call_val).source_location[1] + 2
end

RSpec.describe Lba, ".val" do
  # Exercising the real .current (for real seq/site_seq behavior) memoizes
  # into the process-wide singleton; reset it afterward so it doesn't leak
  # into other spec files' assumptions about starting from a fresh state.
  after { Lba::Internal::CallSiteTracker.instance_variable_set(:@current, nil) }

  # rubocop:disable-next RSpec/ExampleLength -- a full record needs a
  # correspondingly full set of field assertions; splitting it up would
  # obscure that this is one call site producing one complete record.
  it "writes a complete record reflecting the real call site", :aggregate_failures do
    stub_const("Rails", mock_rails(production: false))
    safe_call_site_tracker_current
    sink = StringIO.new

    LbaValIntegrationTestCase.new.call_val(sink:)

    record = JSON.parse(sink.string, symbolize_names: true)
    expect(record[:file]).to end_with("value_spec.rb")
    expect(record[:line]).to eq(LbaValIntegrationTestCase::LINE_OF_VAL_CALL)
    expect(record[:class_name]).to eq("LbaValIntegrationTestCase")
    expect(record[:method_name]).to eq("call_val")
    expect(record[:method_type]).to eq("instance")
    expect(record[:label]).to eq("lba_local_var")
    expect(record[:value]).to eq("traced value")
    expect(record[:value_type]).to eq("String")
    expect(record[:inspected]).to be false
    expect(record[:truncated]).to be false
    expect(record[:schema]).to eq(1)
    expect(record[:type]).to eq("val")
    expect(record[:seq]).to eq(1)
    expect(record[:site_seq]).to eq(1)
    expect(record[:diff]).to be_nil
    expect(record[:run_id]).to eq(Lba::Internal::Run.current.id)
    expect(record[:wall_time]).to be_a(Float)
    expect(record[:mono_time]).to be_a(Float)
  end
end
