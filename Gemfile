source "https://rubygems.org"

gemspec

group :development do
  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rspec", require: false

  gem "irb", require: false # YARD's legacy parser loads irb, not a default gem from Ruby 4.0 on
  gem "yard", require: false
end

group :test do
  gem "logger"
  gem "rspec"
  gem "simplecov", require: false
end

group :development, :test do
  gem "bundler"
end
