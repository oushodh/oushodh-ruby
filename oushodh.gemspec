# frozen_string_literal: true

require_relative "lib/oushodh/version"

Gem::Specification.new do |spec|
  spec.name = "oushodh"
  spec.version = Oushodh::VERSION
  spec.authors = ["Oushodh"]
  spec.email = ["support@oushodh.dev"]
  spec.summary = "Ruby SDK for the Oushodh medicine data API."
  spec.description = "Medicine data for Bangladesh, checked against the DGDA register."
  spec.homepage = "https://oushodh.dev/docs"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/oushodh/oushodh-ruby",
    "changelog_uri" => "https://github.com/oushodh/oushodh-ruby/blob/main/CHANGELOG.md",
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
end
