RSpec.describe 'Loba::VERSION' do
  subject(:version) { Loba::VERSION }

  let(:parts) { version.match(/(\d+).(\d+)(?:.(\d+))?/) }
  let(:major) { parts[1].to_i }
  let(:minor) { parts[2].to_i }
  let(:patch) { parts[3]&.to_i }

  it 'is formatted as major.minor[.patch]' do
    expect(version).to match(/\d+.\d+(?:.\d+)?/)
  end

  it 'is not yet 1.0' do
    expect(major).to be < 1
  end

  it 'is at least 0.4' do
    expect(minor).to be >= 4
  end

  it 'has a patch value' do
    expect(patch).not_to be_nil
  end
end
