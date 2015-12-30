require 'spec_helper'

class LobaClass
  include Loba

  def base
    Loba.ts
    v = "BENJAMIN"
    Loba::ts
    Loba::val :v
  end

  def self.classbase
    Loba::ts
    w = "CLAUDIA"
    Loba::ts
    Loba::val :w
  end
end

describe Loba do
  it 'has a version number' do
    expect(Loba::VERSION).not_to be nil
  end

  context 'ts (timestamp)' do
    let (:test_class) do
      Class.new(LobaClass) do
        def hello
          Loba.ts
          v = "hello"
          Loba::ts
          Loba::val :v
        #  ts  # should fail
          v
        end
      end
    end

    it 'can be called' do
      puts "FOR HELLO"
      expect{test_class.new.hello}.not_to raise_error
    end

    it 'base can be called' do
      puts "IN BASE"
      expect{LobaClass.new.base}.not_to raise_error
    end

    it 'class base can be called' do
      puts "IN CLASS BASE"
      expect{LobaClass.classbase}.not_to raise_error
    end

    it 'can write to STDOUT' do
      expect{test_class.new.hello}.to output(/\[TIMESTAMP\]/).to_stdout
    end

  end
end
