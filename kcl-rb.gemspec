# frozen_string_literal: true

require_relative "lib/kcl/version"

Gem::Specification.new do |spec|
  spec.name          = "kcl-rb"
  spec.version       = Kcl::VERSION
  spec.authors       = ["yo_waka"]
  spec.email         = ["y.wakahara@gmail.com"]

  spec.summary       = "Amazon.Kinesis Client Library for Ruby."
  spec.description   = "A pure ruby interface for Amazon Kinesis Client."
  spec.homepage      = "https://github.com/waka/kcl-rb"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.2")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/waka/kcl-rb"
  spec.metadata["changelog_uri"] = "https://github.com/waka/kcl-rb/CHANGELOG"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 5.0"
  spec.add_dependency "aws-sdk-dynamodb", "~> 1"
  spec.add_dependency "aws-sdk-kinesis", "~> 1"
  spec.add_dependency "eventmachine", "~> 1.2.7"

  spec.add_development_dependency "pry", "~> 0.14"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.11"
  spec.add_development_dependency "rubocop", "~> 1.26"
  spec.add_development_dependency "rubocop-performance", "~> 1.13"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
  spec.add_development_dependency "rubocop-rspec", "~> 2.9"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-lcov"
  spec.add_development_dependency "sorbet"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "undercover-checkstyle"
  spec.metadata["rubygems_mfa_required"] = "true"
end
