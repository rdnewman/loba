require_relative 'loba_class'

RSpec.describe Loba, '.ts' do
  before { LobaSpecSupport::OutputControl.suppress! }

  after { LobaSpecSupport::OutputControl.restore! }

  it 'can be called as Loba.ts' do
    test_class = Class.new do
      def hello
        Loba.ts
      end
    end
    expect { test_class.new.hello }.not_to raise_error
  end

  it 'can be called as Loba.timestamp' do
    test_class = Class.new do
      def hello
        Loba.timestamp
      end
    end
    expect { test_class.new.hello }.not_to raise_error
  end

  it 'cannot be called as ts only' do
    test_class = Class.new do
      def hello
        ts
      end
    end
    expect { test_class.new.hello }.to raise_error NameError
  end

  it 'can be called from instance methods' do
    expect { LobaClass.new.base_ts }.not_to raise_error
  end

  it 'can be called from class methods' do
    expect { LobaClass.classbase_ts }.not_to raise_error
  end

  it 'writes to STDOUT' do
    test_class = Class.new do
      def hello
        Loba.ts
      end
    end
    expect { test_class.new.hello }.to output(/\[TIMESTAMP\]/).to_stdout
  end

  it 'write to STDOUT when invoked as Loba.timestamp' do
    test_class = Class.new do
      def hello
        Loba.timestamp
      end
    end
    expect { test_class.new.hello }.to output(/\[TIMESTAMP\]/).to_stdout
  end

  context 'upon internal error' do
    let(:error_message) { 'fake error' }

    before do
      allow(Loba::Internal::TimeKeeper.instance).to receive(:ping).and_raise(error_message)
    end

    it 'does not raise an error' do
      expect { LobaClass.new.base_ts }.not_to raise_error
    end

    it 'writes to STDOUT' do
      expect { LobaClass.new.base_ts }.to output(/\[TIMESTAMP\]/).to_stdout
    end

    it 'shows the count to be "FAIL"' do
      expect { LobaClass.new.base_ts }.to output(/\[TIMESTAMP\] #=FAIL/).to_stdout
    end

    it 'shows the error message' do
      expect { LobaClass.new.base_ts }.to output(/, err=#{error_message}/).to_stdout
    end
  end

  describe 'colors text' do
    let(:nocolor) { /\e\[0m/ }

    context 'when successful' do
      let(:nobg) { /\e\[49m/ } # default background

      let(:bannercolor) { /\e\[30m/ } # black (foreground)
      let(:bannerbg)    { /\e\[100m/ } # light black (background)
      let(:bannertext)  { /\[TIMESTAMP\]/ } # [TIMESTAMP]
      let(:bannerref)   { /#{bannercolor}#{bannerbg}#{bannertext}#{nocolor}/ }

      let(:labelcolor) { /\e\[33m/ } # yellow (foreground)

      let(:countlabel) { /#{labelcolor}#{nobg}\s#=#{nocolor}\d{4}/ }
      let(:difflabel)  { /#{labelcolor},\sdiff=#{nocolor}\d+\.\d{6}/ }
      let(:atlabel)    { /#{labelcolor},\sat=#{nocolor}\d+\.\d{6}/ }

      let(:codecolor)  { /\e\[90m/ } # dim grey
      let(:codespacer) { /\s*\t/ } # spaces, then tab
      let(:coderef)    { /#{codecolor}#{codespacer}\(in\s.*\)#{nocolor}/ }

      it 'when successful with various colors' do
        test_object = LobaClass.new

        # essentially the same as:
        # "\e[30m\e[100m[TIMESTAMP]\e[0m" \
        # "\e[33m\e[49m #=\e[0m" \
        # '0007' \
        # "\e[33m, diff=\e[0m" \
        # '0.000578' \
        # "\e[33m, at=\e[0m" \
        # '1629403248.858656' \
        # "\e[90m    \t" \
        # '(in=/home/richard/src/loba/spec/loba/loba_class.rb:' \
        # '3' \
        # ":in `base_ts')" \
        # "\e[0m\n"
        colored_output = /#{bannerref}#{countlabel}#{difflabel}#{atlabel}#{coderef}\n/

        expect { test_object.base_ts }.to output(colored_output).to_stdout
      end
    end

    context 'upon error' do
      let(:errorcolor) { /\e\[31m/ } # red

      let(:banner)     { /\[TIMESTAMP\]/ }

      let(:countlabel) { /#=FAIL/ }
      let(:inlabel)    { /in=\/[\w\/]*\/lib\/loba\.rb:\d+:in\s`timestamp'/ }
      let(:errlabel)   { /err=fake\serror/ }
      let(:body)       { /#{countlabel},\s#{inlabel},\s#{errlabel}/ }

      let(:error_message) { 'fake error' }

      before do
        allow(Loba::Internal::TimeKeeper.instance).to receive(:ping).and_raise(error_message)
      end

      it 'with red' do
        # essentially the same as:
        #   "\e[31m" \
        #   '[TIMESTAMP] ' \
        #   '#=FAIL, ' \
        #   "in=/path/to/code/lib/loba.rb:33:in `timestamp'," \
        #   'err=fake error' \
        #   "\e[0m\n"
        colored_output = /#{errorcolor}#{banner}\s#{body}#{nocolor}\n/

        expect { LobaClass.new.base_ts }.to output(colored_output).to_stdout
      end
    end
  end
end
