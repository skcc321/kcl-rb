# typed: false
# frozen_string_literal: true

require "bundler/setup"
# the very top of spec_helper.rb
require "simplecov"
require "simplecov-lcov"
SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
SimpleCov.start do
  add_filter(%r{^/spec/}) # For RSpec
  enable_coverage(:branch) # Report branch coverage to trigger branch-level undercover warnings
end

require "undercover"
require "pry"
require "kcl"

# load shared_contexts
Dir["#{__dir__}/supports/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  true
end

# use localstack
Kcl.configure do |config|
  config.dynamodb_endpoint = "http://localhost:4566"
  config.dynamodb_table_name = "kcl-rb-test"
  config.dynamodb_table_name = "kcl-rb-test"
  config.workers_health_table_name = "kcl-rb-test-health"
  config.kinesis_endpoint = "http://localhost:4566"
  config.kinesis_stream_name = "kcl-rb-test"
  config.logger = Kcl::Logger.new("/dev/null")
end
