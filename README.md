# Lba

Structured, AI-consumable trace-debugging.

Lba is a successor to [loba](https://github.com/rdnewman/loba), rebuilt for a
different primary reader: an AI coding agent (or a human pairing alongside one)
rather than a human eyeballing colorized `$stdout` scrollback.

Status: early build, not yet released.

_This documentation was drafted with AI assistance and reviewed by the author._

## Overview

Lba statements (`Lba.val`, `Lba.ts`) are terse, minimally-invasive, and meant to be
removed when you're done — same ethos as loba. Where loba writes a single
colorized text line, Lba appends one structured JSON record per line to a
per-run log file, so the trace can be aggregated, diffed across runs, and queried
by the `lba` CLI (planned) instead of read raw.

## Usage

### Value records: `Lba.val`

Records a value, with the class, method, file, and line it was called from:

```ruby
class HelloWorld
  def hello(name)
Lba.val :name       # put Lba statements at the far left to help remember to remove them
    "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
```

appends a line like this to the run's file (shown here with some fields left out):

```json
{"type":"val","file":"hello_world.rb","line":3,"class_name":"HelloWorld","method_name":"hello","label":"name","value":"Charlie","value_type":"String"}
```

A Symbol names something in the caller (a local, an instance variable, a method,
or an expression); anything else is recorded as given, optionally with
`label:`. `Lba.value` is an alias.

See [docs/val.md](docs/val.md) for the full record format, options (including
logging to `Rails.logger` or any `Logger`), where records are written, and
limits.

### Timestamp records: `Lba.ts`

Not built yet.

## Environment notes

Lba statements are meant for development and test. Inside a Rails production
environment they do nothing, and unlike loba there is no `production: true`
override: records are written to files meant to be read later, and captured
values are stored as-is, so leaving tracing on in production could persist
secrets or personal data indefinitely.

Records go to `tmp/lba/runs/` under `Rails.root` in Rails, or `.lba/runs/` under
the current directory otherwise. Add that directory to `.gitignore`.

## Installation

Lba isn't published yet. To try it from source, add to your Gemfile:

```ruby
group :development, :test do
  gem "lba", git: "https://github.com/rdnewman/lba"
end
```

Then run `bundle install`. Lba needs Ruby 3.2 or newer.

## Development

After checking out the repo, run `bundle install`. Then:

- `bundle exec rspec` runs the specs.
- `bundle exec rspec --tag performance` runs the timing checks, which are left
  out of the default run because their results depend on the machine.
- `bundle exec rubocop` checks style.
- `bundle exec yard` builds the API documentation.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).
