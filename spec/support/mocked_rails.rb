module MockedRails
  # rubocop:disable-next RSpec/VerifiedDoubles -- Rails isn't loaded, so there's
  # no real constant to verify a double against
  def mock_rails(production:, logger: nil)
    double("Rails", env: double("Rails.env", production?: production), logger:)
  end
end
