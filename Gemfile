# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in agentic.gemspec
gemspec

gem "rake", "~> 13.0"

# CI floor is Ruby 3.2.4: async >= 2.38 / console >= 1.35 need Ruby 3.3,
# io-event >= 1.12 needs Ruby 3.2.6.
gem "async", "<= 2.37.0"
gem "console", "<= 1.34.3"
gem "io-event", "<= 1.11.2"

gem "rspec", "~> 3.0"

gem "standard", "~> 1.3"

gem "vcr"
gem "webmock"
gem "timecop"
