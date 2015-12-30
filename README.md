# Loba

Easy tracing for debugging. Handy methods for adding trace lines to output or Rails logs.

This is my first gem.  You've been warned.

[![Dependency Status](https://gemnasium.com/rdnewman/loba.svg)](https://gemnasium.com/rdnewman/loba)

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

The commands are intended to be terse to minimize typing.  My advise is to align the commands to the far left in your source code so they're easy to remove when you're done.

Quick uses from any ruby code:

#### Timestamp notices

Inserts a timestamped notice either to Rails.logger.debug or to STDOUT if Rails.logger not available.

Useful for quick traces to see the code path and easier than, say, [Kernel#set_trace_func](http://ruby-doc.org/core-2.2.3/Kernel.html#method-i-set_trace_func).
Also does a simple elapsed time check since previous timestamp notice to help with quick, minimalist profiling.

```
Loba::ts    # no arguments
```

#### Variable or method return inspection

Inserts line to Rails.logger.debug (or to STDOUT if Rails.logger not available) showing value with method and class identification

```
Loba::val :var_sym   # the :var_sym argument is the variable or method name given as a symbol
```

TODO: Provide examples

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rdnewman/loba. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
