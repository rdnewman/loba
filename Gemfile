source 'https://rubygems.org'

gemspec

group :development do
  gem 'rubocop', '=1.50.2', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rspec', require: false

  gem 'yard', require: false
end

group :test do
  gem 'codeclimate-test-reporter', require: nil
  gem 'rspec'
  gem 'ruby-prof'
  gem 'simplecov', require: false
end

group :development, :test do
  gem 'bundler'
end
