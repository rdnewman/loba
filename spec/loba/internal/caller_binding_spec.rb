class PlainOldRubyObject
  CAPTURE_LINE = __LINE__ + 2
  def caller_binding
    Loba::Internal::CallerBinding.capture
  end

  def caller_binding_with_local
    local_number = 123
    _ = local_number # for Ruby's -w: only CallerBinding#evaluate reads it
    Loba::Internal::CallerBinding.capture
  end

  def caller_binding_with_reassigned_local
    local_number = 1
    _ = local_number # for Ruby's -w: only CallerBinding#evaluate reads it
    caller_binding = Loba::Internal::CallerBinding.capture
    local_number = 2 # rubocop:disable Lint/UselessAssignment -- read via CallerBinding#evaluate
    caller_binding
  end

  def caller_binding_with_instance_variable
    @instance_number = 456
    Loba::Internal::CallerBinding.capture
  end

  def answer
    42
  end

  def answered?
    true
  end

  def caller_binding_with_local_named_like_a_method
    answer = "local answer"
    _ = answer # for Ruby's -w: only CallerBinding#evaluate reads it
    Loba::Internal::CallerBinding.capture
  end

  def caller_binding_with_hash_local
    greetings = { somename: "Charlie" }
    _ = greetings # for Ruby's -w: only CallerBinding#evaluate reads it
    Loba::Internal::CallerBinding.capture
  end

  @@class_variable_number = 654 # rubocop:disable Style/ClassVars -- read via CallerBinding#evaluate

  def caller_binding_from_lambda
    enclosed_lambda = lambda do
      Loba::Internal::CallerBinding.capture
    end

    enclosed_lambda.call
  end

  define_method(:caller_binding_from_define_method) do
    Loba::Internal::CallerBinding.capture
  end

  def outer
    inner
  end

private

  def inner
    Loba::Internal::CallerBinding.capture(depth: 1)
  end
end

class SubclassOfPlainOldRubyObject < PlainOldRubyObject; end

class NamedRubyClass
  def self.caller_binding
    Loba::Internal::CallerBinding.capture
  end
end

module NamedRubyModule
  def self.caller_binding
    Loba::Internal::CallerBinding.capture
  end
end

class PlainBasicObject < BasicObject
  def caller_binding
    ::Loba::Internal::CallerBinding.capture
  end

  def caller_binding_with_instance_variable
    @basic_number = 99
    ::Loba::Internal::CallerBinding.capture
  end
end

class ClassWithNameTakingArgument
  def self.name(_style) = "unused"

  def caller_binding
    Loba::Internal::CallerBinding.capture
  end
end

class ClassWithNonStringName
  def self.name = 42

  def caller_binding
    Loba::Internal::CallerBinding.capture
  end
end

class CallerBindingReader
  def method_name_of(caller_binding)
    caller_binding.method_name
  end
end

# Each example captures a CallerBinding in the frame under test, then reads it
# after that frame has returned.
RSpec.describe Loba::Internal::CallerBinding do
  describe "#class_name" do
    context "when captured in an instance method" do
      it "returns the real class name" do
        caller_binding = PlainOldRubyObject.new.caller_binding

        expect(caller_binding.class_name).to eq("PlainOldRubyObject")
      end
    end

    context "when captured in an inherited method on a subclass" do
      it "returns the subclass's name, not the ancestor's" do
        caller_binding = SubclassOfPlainOldRubyObject.new.caller_binding

        expect(caller_binding.class_name).to eq("SubclassOfPlainOldRubyObject")
      end
    end

    context "when captured in an instance of an anonymous class" do
      it 'returns "<anonymous class>"' do
        caller_binding = Class.new(PlainOldRubyObject).new.caller_binding

        expect(caller_binding.class_name).to eq("<anonymous class>")
      end
    end

    context "when captured in a class method" do
      it "returns the class's own name" do
        caller_binding = NamedRubyClass.caller_binding

        expect(caller_binding.class_name).to eq("NamedRubyClass")
      end
    end

    context "when captured in a class method on an anonymous class" do
      it 'returns "<anonymous class>"' do
        caller_binding = Class.new(NamedRubyClass).caller_binding

        expect(caller_binding.class_name).to eq("<anonymous class>")
      end
    end

    context "when captured in a module method" do
      it "returns the module's own name" do
        caller_binding = NamedRubyModule.caller_binding

        expect(caller_binding.class_name).to eq("NamedRubyModule")
      end
    end

    context "when captured in a BasicObject's instance method" do
      it "returns the real class name" do
        caller_binding = PlainBasicObject.new.caller_binding

        expect(caller_binding.class_name).to eq("PlainBasicObject")
      end
    end

    context "when captured in an instance of an anonymous class that names itself" do
      it "returns the name the class gives" do
        self_named_class = Class.new(PlainOldRubyObject) { def self.name = "User" }

        caller_binding = self_named_class.new.caller_binding

        expect(caller_binding.class_name).to eq("User")
      end
    end

    context "when captured in a class whose own name method raises" do
      it "returns the class's constant name" do
        caller_binding = ClassWithNameTakingArgument.new.caller_binding

        expect(caller_binding.class_name).to eq("ClassWithNameTakingArgument")
      end
    end

    context "when captured in a class whose own name method returns a non-String" do
      it "returns the class's constant name" do
        caller_binding = ClassWithNonStringName.new.caller_binding

        expect(caller_binding.class_name).to eq("ClassWithNonStringName")
      end
    end

    context "when captured at the top level of a script" do
      it 'returns "Object"' do
        caller_binding = TOPLEVEL_BINDING.eval("Loba::Internal::CallerBinding.capture")

        expect(caller_binding.class_name).to eq("Object")
      end
    end
  end

  describe "#method_type" do
    context "when captured in an instance method" do
      it "returns :instance" do
        caller_binding = PlainOldRubyObject.new.caller_binding

        expect(caller_binding.method_type).to eq(:instance)
      end
    end

    context "when captured in a class method" do
      it "returns :class" do
        caller_binding = NamedRubyClass.caller_binding

        expect(caller_binding.method_type).to eq(:class)
      end
    end

    context "when captured in a module method" do
      it "returns :class" do
        caller_binding = NamedRubyModule.caller_binding

        expect(caller_binding.method_type).to eq(:class)
      end
    end

    context "when captured in a BasicObject's instance method" do
      it "returns :instance" do
        caller_binding = PlainBasicObject.new.caller_binding

        expect(caller_binding.method_type).to eq(:instance)
      end
    end
  end

  describe "#method_name" do
    context "when captured in an instance method" do
      it "returns that method's name" do
        caller_binding = PlainOldRubyObject.new.caller_binding

        expect(caller_binding.method_name).to eq(:caller_binding)
      end
    end

    # __method__ is lexical: a lambda inside a `def` reports that def's name,
    # though the lambda itself has none.
    context "when captured in a lambda within a method" do
      it "returns the enclosing method's name" do
        caller_binding = PlainOldRubyObject.new.caller_binding_from_lambda

        expect(caller_binding.method_name).to eq(:caller_binding_from_lambda)
      end
    end

    # Rare but real: a bare script or a top-level rake task body.
    context "when captured in a lambda outside any method" do
      it 'returns "<anonymous method>"' do
        caller_binding = -> { described_class.capture }.call

        expect(caller_binding.method_name).to eq("<anonymous method>")
      end
    end

    context "when captured in a method defined with define_method" do
      it "returns the defined method's name" do
        caller_binding = PlainOldRubyObject.new.caller_binding_from_define_method

        expect(caller_binding.method_name).to eq(:caller_binding_from_define_method)
      end
    end
  end

  describe "#file" do
    it "returns the path of the file it was captured in" do
      caller_binding = PlainOldRubyObject.new.caller_binding

      expect(caller_binding.file).to eq(__FILE__)
    end

    context "when captured in eval'd code" do
      it "returns the file name eval was given" do
        caller_binding =
          TOPLEVEL_BINDING.eval("Loba::Internal::CallerBinding.capture", "script.rb", 7)

        expect(caller_binding.file).to eq("script.rb")
      end
    end
  end

  describe "#line" do
    it "returns the line it was captured on" do
      caller_binding = PlainOldRubyObject.new.caller_binding

      expect(caller_binding.line).to eq(PlainOldRubyObject::CAPTURE_LINE)
    end
  end

  describe "#source_line" do
    it "returns a caller-style file:line:in string for where it was captured" do
      caller_binding = PlainOldRubyObject.new.caller_binding
      location = "#{__FILE__}:#{PlainOldRubyObject::CAPTURE_LINE}:in "

      expect(caller_binding.source_line).to start_with(location).and end_with("caller_binding'")
    end
  end

  describe "#evaluate" do
    context "when given a symbol naming a local" do
      it "returns the value of that local in the frame it was captured in" do
        caller_binding = PlainOldRubyObject.new.caller_binding_with_local

        expect(caller_binding.evaluate(:local_number)).to eq(123)
      end
    end

    # The binding is live: it reads locals when evaluated, not when captured.
    context "when the local is reassigned after the binding is captured" do
      it "returns the local's value at evaluation time" do
        caller_binding = PlainOldRubyObject.new.caller_binding_with_reassigned_local

        expect(caller_binding.evaluate(:local_number)).to eq(2)
      end
    end

    context "when a local has the same name as a method" do
      it "returns the local, not the method's result" do
        caller_binding = PlainOldRubyObject.new.caller_binding_with_local_named_like_a_method

        expect(caller_binding.evaluate(:answer)).to eq("local answer")
      end
    end

    context "when given a symbol naming an instance variable" do
      it "returns that instance variable's value" do
        caller_binding = PlainOldRubyObject.new.caller_binding_with_instance_variable

        expect(caller_binding.evaluate(:@instance_number)).to eq(456)
      end

      it "returns nil when the instance variable was never set" do
        caller_binding = PlainOldRubyObject.new.caller_binding

        expect(caller_binding.evaluate(:@never_set)).to be_nil
      end

      it "reads it from a BasicObject" do
        caller_binding = PlainBasicObject.new.caller_binding_with_instance_variable

        expect(caller_binding.evaluate(:@basic_number)).to eq(99)
      end
    end

    context "when given a symbol naming a class variable" do
      it "returns that class variable's value" do
        caller_binding = PlainOldRubyObject.new.caller_binding

        expect(caller_binding.evaluate(:@@class_variable_number)).to eq(654)
      end
    end

    context "when given a symbol naming a global variable" do
      it "returns that global's value" do
        caller_binding = PlainOldRubyObject.new.caller_binding

        expect(caller_binding.evaluate(:$PROGRAM_NAME)).to eq($PROGRAM_NAME)
      end
    end

    # Supports tracing methods such as :params or :current_user.
    context "when given a symbol naming a method" do
      it "calls the method and returns its result" do
        caller_binding = PlainOldRubyObject.new.caller_binding

        expect(caller_binding.evaluate(:answer)).to eq(42)
      end

      it "calls a predicate method" do
        caller_binding = PlainOldRubyObject.new.caller_binding

        expect(caller_binding.evaluate(:answered?)).to be true
      end
    end

    context "when given :self" do
      it "returns the object it was captured in" do
        object = PlainOldRubyObject.new

        caller_binding = object.caller_binding

        expect(caller_binding.evaluate(:self)).to equal(object)
      end
    end

    # The documented form (docs/val.md, Example 2) for expressions a bare
    # Symbol can't spell.
    context "when given an expression cast to a Symbol" do
      it "evaluates the expression in the frame it was captured in" do
        caller_binding = PlainOldRubyObject.new.caller_binding_with_hash_local

        expect(caller_binding.evaluate(:"greetings[:somename]")).to eq("Charlie")
      end
    end

    context "when given a symbol naming a constant" do
      it "returns the constant as seen from the frame it was captured in" do
        caller_binding = PlainOldRubyObject.new.caller_binding

        expect(caller_binding.evaluate(:CAPTURE_LINE)).to eq(PlainOldRubyObject::CAPTURE_LINE)
      end
    end

    context "when given a symbol that names nothing in the frame" do
      it "raises NameError" do
        caller_binding = PlainOldRubyObject.new.caller_binding

        expect { caller_binding.evaluate(:undefined_name) }
          .to raise_error(NameError, /undefined_name/)
      end
    end

    # A typo in an expression cast to a Symbol is the usual way to get one.
    context "when given a symbol that isn't valid Ruby" do
      it "raises SyntaxError" do
        caller_binding = PlainOldRubyObject.new.caller_binding_with_hash_local

        expect { caller_binding.evaluate(:"greetings[:somename") }.to raise_error(SyntaxError)
      end
    end

    context "when given anything other than a symbol" do
      it "returns the argument unchanged without evaluating it as code" do
        caller_binding = PlainOldRubyObject.new.caller_binding
        invalid_ruby_code = "this is not valid ruby !!"

        expect(caller_binding.evaluate(invalid_ruby_code)).to equal(invalid_ruby_code)
      end

      it "returns a BasicObject unchanged, though it has no #is_a?" do
        caller_binding = PlainOldRubyObject.new.caller_binding
        basic_object = BasicObject.new

        expect(caller_binding.evaluate(basic_object)).to equal(basic_object)
      end
    end
  end

  context "when read from a different frame than it was captured in" do
    it "still describes the frame it was captured in" do
      caller_binding = PlainOldRubyObject.new.caller_binding

      expect(CallerBindingReader.new.method_name_of(caller_binding)).to eq(:caller_binding)
    end
  end

  context "when captured with depth: 1" do
    it "describes the caller of the method that captured it" do
      caller_binding = PlainOldRubyObject.new.outer

      expect(caller_binding.method_name).to eq(:outer)
    end
  end

  # Taken inside #initialize, a snapshot would count Class#new's frame on
  # Rubies that have one, and land a frame short of the caller.
  describe ".new" do
    it "is private, so every CallerBinding is taken by .capture" do
      expect { described_class.new(location: nil, frame_self: nil, frame_binding: nil) }
        .to raise_error(NoMethodError, /private method/)
    end
  end
end
