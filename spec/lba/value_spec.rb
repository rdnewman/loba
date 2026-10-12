require "json"
require "logger"
require "stringio"

class LbaValIntegrationTestCase
  def call_val(**)
    lba_local_var = "traced value" # rubocop:disable Lint/UselessAssignment -- read via Lba.value's eval
    Lba.value(:lba_local_var, **)
  end

  LINE_OF_VAL_CALL = instance_method(:call_val).source_location[1] + 2
end

# One call site per caller context Lba.value has to reflect on correctly.
# Symbol arguments name locals that only Lba.value reads, through the caller's
# binding.
class LbaValCallerContexts
  def self.from_class_method(sink:)
    class_local = 7 # rubocop:disable Lint/UselessAssignment -- read via Lba.value's eval
    Lba.value(:class_local, sink:)
  end

  FROM_CLASS_METHOD_LINE = method(:from_class_method).source_location[1] + 2

  def with_instance_variable(sink:)
    @traced = "ivar value"
    Lba.value(:@traced, sink:)
  end

  def with_non_symbol(sink:)
    Lba.value("direct value", sink:)
  end

  def with_explicit_label(sink:)
    labeled_local = "labeled value" # rubocop:disable Lint/UselessAssignment -- read via Lba.value's eval
    Lba.value(:labeled_local, label: "Custom label", sink:)
  end

  def with_inspect_disabled(sink:)
    @traced = "ivar value"
    Lba.value(:self, inspect: false, sink:)
  end

  def through_alias(sink:)
    Lba.val("aliased value", sink:)
  end

  def within_block(sink:)
    [1].each do |item| # rubocop:disable Lint/UnusedBlockArgument -- read via Lba.value's eval
      Lba.value(:item, sink:)
    end
  end

  WITHIN_BLOCK_LINE = instance_method(:within_block).source_location[1] + 2

  def within_lambda(sink:)
    tracer = lambda do
      lambda_local = "lambda value" # rubocop:disable Lint/UselessAssignment -- read via Lba.value's eval
      Lba.value(:lambda_local, sink:)
    end
    tracer.call
  end

  WITHIN_LAMBDA_LINE = instance_method(:within_lambda).source_location[1] + 3

  def with_undefined_name(sink:)
    Lba.value(:undefined_name, sink:)
  end

  def with_raising_method(sink:)
    Lba.value(:raising_method, sink:)
  end

  def with_interrupting_method(sink:)
    Lba.value(:interrupting_method, sink:)
  end

  def with_binary_string(sink:)
    payload = "\xFF\xFE".b # rubocop:disable Lint/UselessAssignment -- read via Lba.value's eval
    Lba.value(:payload, sink:)
  end

  def with_nan(sink:)
    ratio = 0.0 / 0.0 # rubocop:disable Lint/UselessAssignment -- read via Lba.value's eval
    Lba.value(:ratio, sink:)
  end

  def with_basic_object(sink:)
    proxy = BasicObject.new # rubocop:disable Lint/UselessAssignment -- read via Lba.value's eval
    Lba.value(:proxy, sink:)
  end

  def with_partly_unrenderable(sink:)
    items = [1, BasicObject.new, 3] # rubocop:disable Lint/UselessAssignment -- read via Lba.value's eval
    Lba.value(:items, sink:)
  end

  def raising_method
    raise ArgumentError, "boom"
  end

  def interrupting_method
    raise Interrupt
  end
end

class LbaValCallerContextsSubclass < LbaValCallerContexts; end

RSpec.describe Lba, ".value" do
  # The real .current memoizes the process's visits; reset them so other
  # specs start fresh.
  after do
    reset_current(Lba::Internal::Run::Visits)
  end

  def written_record(sink)
    JSON.parse(sink.string, symbolize_names: true)
  end

  # Logger prefixes each line with its own severity and timestamp; the record
  # is the JSON object after that.
  def logged_record(log_output)
    JSON.parse(log_output.string[/\{.*\}/], symbolize_names: true)
  end

  # rubocop:disable-next RSpec/ExampleLength -- one call, one complete record;
  # splitting the field checks would hide that.
  it "writes a complete record reflecting the real call site", :aggregate_failures do
    stub_const("Rails", mock_rails(production: false))
    stub_visits_at_exit
    sink = StringIO.new

    LbaValIntegrationTestCase.new.call_val(sink:)

    record = written_record(sink)
    # The written line is also read raw (tail, grep, truncated output), so its
    # fields come in the same order on every line.
    expect(record.keys).to eq(
      [:seq, :type, :label, :file, :line, :class_name, :method_name, :method_type,
       :site_seq, :diff, :value_type, :value,
       :wall_time, :mono_time, :run_id, :schema]
    )
    expect(record[:file]).to end_with("value_spec.rb")
    expect(record[:line]).to eq(LbaValIntegrationTestCase::LINE_OF_VAL_CALL)
    expect(record[:class_name]).to eq("LbaValIntegrationTestCase")
    expect(record[:method_name]).to eq("call_val")
    expect(record[:method_type]).to eq("instance")
    expect(record[:label]).to eq("lba_local_var")
    expect(record[:value]).to eq("traced value")
    expect(record[:value_type]).to eq("String")
    expect(record[:schema]).to eq(1)
    expect(record[:type]).to eq("val")
    expect(record[:seq]).to eq(1)
    expect(record[:site_seq]).to eq(1)
    expect(record[:diff]).to be_nil
    expect(record[:run_id]).to eq(Lba::Internal::Run.current.id)
    expect(record[:wall_time]).to be_a(Float)
    expect(record[:mono_time]).to be_a(Float)
  end

  it "writes the record counting a capped site's skipped calls in a fixed field order" do
    hooks = stub_visits_at_exit
    sink = StringIO.new
    501.times { described_class.value("looped", sink:) }

    hooks.first.call

    suppression = JSON.parse(sink.string.lines.last, symbolize_names: true)
    expect(suppression.keys).to eq(
      [:seq, :type, :file, :line, :suppressed, :suppressed_count,
       :wall_time, :mono_time, :run_id, :schema]
    )
  end

  it "times a record exactly as the gap since its site's previous line's mono_time" do
    stub_visits_at_exit
    sink = StringIO.new
    test_case = LbaValIntegrationTestCase.new
    test_case.call_val(sink:)

    test_case.call_val(sink:)

    first, second = sink.string.lines.map { JSON.parse(_1, symbolize_names: true) }
    expect(second[:diff]).to eq(second[:mono_time] - first[:mono_time])
  end

  context "when the process forks after an earlier call" do
    it "writes the child's records under its own run and sequence", :aggregate_failures do
      stub_visits_at_exit
      parent_sink = StringIO.new
      described_class.value("from parent", sink: parent_sink)
      parent_run_id = written_record(parent_sink)[:run_id]

      child_record = in_forked_child do
        child_sink = StringIO.new
        described_class.value("from child", sink: child_sink)
        written_record(child_sink)
      end

      expect(child_record[:run_id]).not_to eq(parent_run_id)
      expect(child_record).to include(seq: 1, value: "from child")
    end
  end

  context "when capturing an instance variable by Symbol" do
    it "evaluates it on the calling instance" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.with_instance_variable(sink:)

      expect(written_record(sink)).to include(
        label: "@traced", value: "ivar value",
        class_name: "LbaValCallerContexts", method_name: "with_instance_variable",
        method_type: "instance"
      )
    end
  end

  context "when called by its alias, Lba.val" do
    it "writes the same kind of record as Lba.value" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.through_alias(sink:)

      expect(written_record(sink)).to include(value: "aliased value", method_name: "through_alias")
    end
  end

  context "when called without the Lba namespace" do
    it "is not available as a bare val" do
      expect { Object.new.instance_eval { val(:anything) } }
        .to raise_error(NoMethodError, /undefined method 'val'/)
    end
  end

  context "when given an explicit label" do
    it "records that label instead of inferring one from the Symbol" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.with_explicit_label(sink:)

      expect(written_record(sink)).to include(label: "Custom label", value: "labeled value")
    end
  end

  context "when given inspect: false" do
    it "renders a value it can't represent natively with #to_s instead of #inspect" do
      stub_visits_at_exit
      sink = StringIO.new
      caller_contexts = LbaValCallerContexts.new

      caller_contexts.with_inspect_disabled(sink:)

      expect(written_record(sink)).to include(label: "self", value: caller_contexts.to_s)
    end
  end

  context "when given a non-Symbol value" do
    it "records the value as-is, with no label" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.with_non_symbol(sink:)

      expect(written_record(sink)).to include(
        label: nil, value: "direct value", method_name: "with_non_symbol"
      )
    end
  end

  context "when called inside a block within a method" do
    it "reads the block's own locals and reports the enclosing method" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.within_block(sink:)

      expect(written_record(sink)).to include(
        label: "item", value: 1, method_name: "within_block",
        line: LbaValCallerContexts::WITHIN_BLOCK_LINE
      )
    end
  end

  context "when called inside a lambda within a method" do
    it "reads the lambda's own locals and reports the enclosing method" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.within_lambda(sink:)

      expect(written_record(sink)).to include(
        label: "lambda_local", value: "lambda value", method_name: "within_lambda",
        line: LbaValCallerContexts::WITHIN_LAMBDA_LINE
      )
    end
  end

  context "when called from a class method" do
    it "reports the class itself and a :class method type" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.from_class_method(sink:)

      expect(written_record(sink)).to include(
        class_name: "LbaValCallerContexts", method_name: "from_class_method",
        method_type: "class", value: 7, line: LbaValCallerContexts::FROM_CLASS_METHOD_LINE
      )
    end
  end

  context "when called from an inherited method on a subclass" do
    it "reports the subclass, not the class that defined the method" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContextsSubclass.new.with_non_symbol(sink:)

      expect(written_record(sink)).to include(class_name: "LbaValCallerContextsSubclass")
    end
  end

  context "when called from an instance of an anonymous class" do
    it "reports a placeholder class name" do
      stub_visits_at_exit
      sink = StringIO.new

      Class.new(LbaValCallerContexts).new.with_non_symbol(sink:)

      expect(written_record(sink)).to include(class_name: "<anonymous class>")
    end
  end

  # One call writes to the sink and mirrors to the logger: both, not either.
  context "when mirroring to a logger", :aggregate_failures do
    it "writes the same record to the sink and to the given logger" do
      stub_visits_at_exit
      sink = StringIO.new
      log_output = StringIO.new

      LbaValIntegrationTestCase.new.call_val(sink:, logger: Logger.new(log_output))

      expect(written_record(sink)).to include(value: "traced value")
      expect(logged_record(log_output)).to eq(written_record(sink))
    end

    # Otherwise a log reader would see a capped loop's records stop, as if the
    # loop had ended.
    it "also logs the record counting a capped site's skipped calls" do
      hooks = stub_visits_at_exit
      sink = StringIO.new
      log_output = StringIO.new
      logger = Logger.new(log_output)
      501.times { described_class.value("looped", sink:, logger:) }

      hooks.first.call

      last_logged = JSON.parse(log_output.string.lines.last[/\{.*\}/], symbolize_names: true)
      expect(last_logged).to include(suppressed: true, suppressed_count: 1)
    end

    it "writes to the sink and to Rails.logger when log: true inside Rails" do
      stub_visits_at_exit
      sink = StringIO.new
      rails_log_output = StringIO.new
      stub_const("Rails", mock_rails(logger: Logger.new(rails_log_output)))

      LbaValIntegrationTestCase.new.call_val(sink:, log: true)

      expect(written_record(sink)).to include(value: "traced value")
      expect(logged_record(rails_log_output)).to eq(written_record(sink))
    end

    it "writes only to the sink by default, even inside Rails" do
      stub_visits_at_exit
      sink = StringIO.new
      rails_log_output = StringIO.new
      stub_const("Rails", mock_rails(logger: Logger.new(rails_log_output)))

      LbaValIntegrationTestCase.new.call_val(sink:)

      expect(written_record(sink)).to include(value: "traced value")
      expect(rails_log_output.string).to be_empty
    end
  end

  # A tracing call must never break the code it traces.
  context "when evaluating a Symbol raises" do
    it "does not raise into the calling code" do
      stub_visits_at_exit
      sink = StringIO.new

      expect { LbaValCallerContexts.new.with_undefined_name(sink:) }.not_to raise_error
    end

    it "records the error in place of the value", :aggregate_failures do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.with_undefined_name(sink:)

      record = written_record(sink)
      expect(record).to include(label: "undefined_name", method_name: "with_undefined_name")
      expect(record[:errors]).to contain_exactly(
        { path: [], message: start_with("NameError: ").and(include("undefined_name")) }
      )
      expect(record.keys).not_to include(:value, :value_type)
    end

    it "records a traced method's own error" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.with_raising_method(sink:)

      expect(written_record(sink))
        .to include(errors: [{ path: [], message: "ArgumentError: boom" }])
    end

    it "lets exceptions outside StandardError, such as Interrupt, through" do
      stub_visits_at_exit
      sink = StringIO.new

      expect { LbaValCallerContexts.new.with_interrupting_method(sink:) }.to raise_error(Interrupt)
    end
  end

  # Each of these once raised while writing the record's JSON line.
  context "when the value has no exact JSON form" do
    # The text can look exactly like a real String, so the record names it.
    it "names each part recorded as text, and why, before the value", :aggregate_failures do
      stub_visits_at_exit
      sink = StringIO.new

      described_class.value({ total: Float::NAN, note: "NaN" }, sink:)

      record = written_record(sink)
      expect(record[:rendered]).to eq([{ path: ["total"], as: "non_finite" }])
      expect(record.keys.index(:rendered)).to be < record.keys.index(:value)
    end

    it "lists Hash keys that collide as JSON text, before the value", :aggregate_failures do
      stub_visits_at_exit
      sink = StringIO.new

      described_class.value({ id: 1, "id" => 2 }, sink:)

      record = written_record(sink)
      expect(record[:value]).to eq(id: 1)
      expect(record[:collided])
        .to eq([{ path: [], key: "id", pairs: [[":id", "1"], ["\"id\"", "2"]] }])
      expect(record.keys.index(:collided)).to be < record.keys.index(:value)
    end

    it "names each part cut short, and how much, before the value", :aggregate_failures do
      stub_visits_at_exit
      sink = StringIO.new

      described_class.value({ items: Array.new(53, 0) }, sink:)

      record = written_record(sink)
      expect(record[:cut]).to eq([{ path: ["items"], omitted: 3, unit: "entries" }])
      expect(record[:value][:items].size).to eq(50)
      expect(record.keys.index(:cut)).to be < record.keys.index(:value)
    end

    it "records binary data as its #inspect text" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.with_binary_string(sink:)

      expect(written_record(sink)).to include(value: "\"\\xFF\\xFE\"")
    end

    it "records NaN as text" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.with_nan(sink:)

      expect(written_record(sink)).to include(value: "NaN", value_type: "Float")
    end

    it "records an object that can't be rendered as an error" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.with_basic_object(sink:)

      expect(written_record(sink)).to include(
        label: "proxy",
        errors: [{ path: [], message: start_with("NoMethodError: undefined method 'inspect'") }]
      )
    end

    it "keeps what it can of a container and reports the part it couldn't" do
      stub_visits_at_exit
      sink = StringIO.new

      LbaValCallerContexts.new.with_partly_unrenderable(sink:)

      expect(written_record(sink)).to include(
        value: [1, "(unrenderable)", 3],
        errors: [{ path: [1], message: start_with("NoMethodError: undefined method 'inspect'") }]
      )
    end
  end
end
