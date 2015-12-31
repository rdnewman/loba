[![Dependency Status](https://gemnasium.com/rdnewman/loba.svg)](https://gemnasium.com/rdnewman/loba)
[![Build Status](https://travis-ci.org/rdnewman/loba.svg?branch=master)](https://travis-ci.org/rdnewman/loba)
[![Code Climate](https://codeclimate.com/github/rdnewman/loba/badges/gpa.svg)](https://codeclimate.com/github/rdnewman/loba)
[![Issue Count](https://codeclimate.com/github/rdnewman/loba/badges/issue_count.svg)](https://codeclimate.com/github/rdnewman/loba)
[![Test Coverage](https://codeclimate.com/github/rdnewman/loba/badges/coverage.svg)](https://codeclimate.com/github/rdnewman/loba/coverage)
[![security](https://hakiri.io/github/rdnewman/loba/master.svg)](https://hakiri.io/github/rdnewman/loba/master)

# Loba

![Loba is "write" in zulu](readme/zulu.png)

Easy tracing for debugging: handy methods for adding trace lines to output or Rails logs.

## Usage

There are two kinds of questions I usually want to answer when trying to diagnose code behavior:
1. Is this spot of code being reached (or is it reached in the order I think it is)?
1. What is the value of this variable?

I wanted a quick way to check that lets me run the code as it normally runs with the least amount of impact to the code behavior, so I would typically just drop in `puts` (e.g., STDOUT) or `Rails.logger.info` (environmental log) to check.  That became tedious after a while, so being a naturally lazy person (i.e., developer), I decided to make it easier.

Loba statements are intended to be terse to minimize typing.  My advise is to align the commands to the far left in your source code so they're easy to see and remove when you're done.

Loba will check for presence of Rails.  If it's there, it'll write to `Rails.logger.debug`.  If not, it'll write to STDOUT (i.e., `puts`).  Loba will work equally well with or without Rails.

Quick uses from any ruby code:

#### Timestamp notices:  `Loba::ts`

Outputs a timestamped notice, useful for quick traces to see the code path and easier than, say, [Kernel#set_trace_func](http://ruby-doc.org/core-2.2.3/Kernel.html#method-i-set_trace_func).
Also does a simple elapsed time check since the previous timestamp notice to help with quick, minimalist profiling.

For example,

```
[TIMESTAMP] #=0002, diff=93.478016, at=1451444972.970602, in=/home/usracct/src/myapp/app/models/target.rb:55:in `some_calculation'
```

To invoke,

```
Loba::ts    # no arguments
```

The resulting notice output format is

```
[TIMESTAMP] #=nnnn, diff=ss.ssssss, at=tttttttttt.tttttt, in=/path/to/code/somecode.rb:ll:in 'some_method'
```

where 
* `nnn` ("#=") is a sequential numbering (1, 2, 3, ...) of timestamp notices,
* `ss.ssssss` ("diff=") is number of seconds since the last timestamp notice was output (i.e., relative time),
* `tttttttttt.tttttt` ("at=") is Time.now (as seconds) (i.e., absolute time),
* `/path/to/code/somecode.rb` ("in=") is the source code file that invoked `Loba::ts`,
* `ll` ("in=...:") is the line number of the source code file that invoked `Loba::ts`, and
* `some_method`is the method in which `Loba::ts` was invoked.


#### Variable or method return inspection

Inserts line to Rails.logger.debug (or to STDOUT if Rails.logger not available) showing value with method and class identification

```
Loba::val :var_sym   # the :var_sym argument is the variable or method name given as a symbol
```

TODO: Provide examples

## Installation

Add this line to your application's Gemfile:

```ruby
group :development, :test do
  gem 'loba', require: false, github: 'rdnewman/loba'   # until I publish it on RubyGems
end
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install loba

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rdnewman/loba. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
