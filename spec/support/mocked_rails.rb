module MockedRails
  # rubocop:disable-next RSpec/VerifiedDoubles -- Rails isn't loaded, so there's
  # no real constant to verify a double against
  def mock_rails(production: false, logger: nil)
    double("Rails", env: double("Rails.env", production?: production), logger:)
  end

  # rubocop:disable-next RSpec/VerifiedDoubles -- stands in for a real Rails.logger,
  # which has no fixed class to verify a double against
  def fake_rails_logger = double("Rails.logger")
end
