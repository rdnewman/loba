# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog (1.0.0)](https://keepachangelog.com/en/1.0.0/),
and, as of version 0.3.0 and later, this project adheres to [Semantic Versioning (2.0.0)](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.0] - 2024-09-09
### Added
- Added `logger` option for accepting a logger to write to instead of default behavior
- Added `logdev` option to direct logging in non-Rails environments
- Added `out` option to allow turning off console (`puts`) output

### Changed
- Changed so `log` option will allow logging in non-Rails environments
- Changed so `log` option will be defaulted to `true` when `out` options is set to `false`
- Updated documentation for new and changed options and to improve completeness
- Refreshed gems and dependencies

## [2.0.0] - 2023-07-07
### Added
- `Loba.ts`: `log` option to allow logging to Rails.logger (ignored if unavailable)
- `Loba.val`: `log` option to allow logging to Rails.logger (ignored if unavailable)
- SECURITY.md to specify security policy

### Changed
- Dropped support for Ruby prior to 3.0.6
- Changed output to always write to `$stdout` (regardless whether Rails is present)
- Changed to only write to Rails.logger (when present) when `log` option is set to `true`
- Updated YARD documentation for improved completeness
- Refreshed gems and dependencies

## [1.2.1] - 2021-09-05
### Added
- Optional specs for developers to check Loba performance (no surprising issues found)

### Changed
- Updated README reference links
- Updated to support Ruby 2.2.2 as minimum (retreated from 2.5 for broader support)
- Refactored to separate stripping quotes from .inspect-generated strings

## [1.2.0] - 2021-09-05 [YANKED]

## [1.1.0] - 2021-08-20
### Added
- CHANGELOG.md to follow "Keep a Changelog" convention
- minor unit tests

### Changed
- Replaced colorize gem with rainbow gem for MIT license purity
- "Changelog" section of README.md to refer to new CHANGELOG.md
- `Loba.ts`: "(in ...)" of notice now has a space instead of a "=" (matches `Loba.val`)
- `Loba.ts`: string continuation instead of concatenation for performance
- `Loba.val`: string continuation instead of concatenation for performance

## [1.0.0] - 2021-08-18
### Added
- `Loba.val`: added `Loba.value` as an alias

### Changed
- `Loba.ts`: use Ruby 2.x-style keyword arguments instead of an options hash [BREAKING CHANGE]
- `Loba.val`: use Ruby 2.x-style keyword arguments instead of an options hash [BREAKING CHANGE]
- Updated for more recent Ruby versions (>= 2.5)
- Updated gem dependencies
- Expanded unit testing
- Refactored code to better compartmentalize for easier maintainability
- Updated user documentation, including corrections and better `production: true` warning
- Updated YARD documentation

### Removed
- Gemnasium link from README
- Last positional argument as `true` or `false` to control presence in production environments
- Options hash support to control `production: true` and `inspect: false` [BREAKING CHANGE]

## [0.3.1] - 2017-04-07
### Added
- YARD documentation
- `Loba.val`: `inspect` option to control use of `.inspect` on an argument value
- `Loba.ts`: added `Loba.timestamp` as an alias

### Changed
- Converted to options hash instead of implicit positional arguments
- `Loba.val`: nil values now display as `-nil-` instead of blank output

### Deprecated
- Last positional argument as `true` or `false` to control presence in production environments

## [0.3.0] - 2017-04-07 [YANKED]

## [0.2.0] - 2016-12-02
### Added
- Initial publication to RubyGems.org
- Gem badge to README
- Code Climate integration

### Changed
- Improved and corrected documentation
- Various bug fixes
- Generalized for Ruby and reduced Rails centricity

## 0.1.0 - 2016-01-06
### Added
- Initial implementation

[Unreleased]: https://github.com/rdnewman/loba/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/rdnewman/loba/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/rdnewman/loba/compare/v1.2.1...v2.0.0
[1.2.1]: https://github.com/rdnewman/loba/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/rdnewman/loba/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/rdnewman/loba/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/rdnewman/loba/compare/v0.3.1...v1.0.0
[0.3.1]: https://github.com/rdnewman/loba/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/rdnewman/loba/compare/0.2.0...v0.3.0
[0.2.0]: https://github.com/olivierlacan/keep-a-changelog/releases/tag/0.2.0
