RSpec.describe 'Loba::VERSION' do
  subject(:version) { Loba::VERSION }

  let(:parts) { version.match(/(\d+).(\d+)(?:.(\d+))?/) }
  let(:major) { parts[1].to_i }
  let(:minor) { parts[2].to_i }
  let(:patch) { parts[3]&.to_i }

  it 'has a version number' do
    expect(version).not_to be_nil
  end

  it 'is formatted as major.minor[.patch]' do
    expect(version).to match(/\d+.\d+(?:.\d+)?/)
  end

  # ensure updates to VERSION are intentional
  it 'is 2.x' do
    expect(major).to eq 2
  end

  it 'is 2.0.x or later' do
    expect(minor).to be >= 0
  end

  it 'has a patch value' do
    expect(patch).not_to be_nil
  end
end
