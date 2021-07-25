RSpec.describe Loba::Internal::TimeKeeper do
  subject(:timekeeper) { described_class.instance }

  it 'to know the last time it was called' do
    expect(timekeeper.timewas).to be < Time.now
  end

  it 'to start at zero times called' do
    expect(timekeeper.timenum.zero?).to be true
  end

  describe '#reset!' do
    before { timekeeper.ping } # make sure it's been invoked before

    it 'forces the number of times it has been called back to zero' do
      expect { timekeeper.reset! }.to change(timekeeper, :timenum).to(0)
    end

    it 'updates the last time it was called' do
      expect { timekeeper.reset! }.to change(timekeeper, :timewas)
    end
  end

  describe '#ping' do
    it 'increments number of times it was called' do
      expect { timekeeper.ping }.to change(timekeeper, :timenum).by(1)
    end

    it 'updates the last time it was called' do
      expect { timekeeper.ping }.to change(timekeeper, :timewas)
    end

    it 'reports the number of times it has been called' do
      timekeeper.reset!

      expect(timekeeper.ping[:number]).to eq 1
    end

    it 'reports the time of when it is currently called' do
      expect(timekeeper.ping[:now]).to be_within(0.005).of Time.now
    end

    it 'reports how long since it was last called' do
      timewas = timekeeper.timewas

      ping = timekeeper.ping
      expect(ping[:change]).to eq(ping[:now] - timewas)
    end
  end
end
