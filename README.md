# Loba

Easy tracing for debugging. Handy methods for adding trace lines to output or Rails logs.

This is my first gem.  You've been warned.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'loba'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install loba

## Usage

Quick uses from any ruby code:

#### Timestamp notices

Useful for quick traces to see the code path and easier than, say, [Kernel#set_trace_func](http://ruby-doc.org/core-2.2.3/Kernel.html#method-i-set_trace_func).

```
Loba::ts   # inserts timestamp notice either to Rails.logger.debug or to STDOUT if Rails.logger not available
```

#### Variable or method return inspection

```
Loba::val :var_sym   # inserts line showing value with method and class identification
```

TODO: Provide examples

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rdnewman/loba. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
