# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'smart_enum/version'

require_relative '../../lib/match_shipit_version'

Gem::Specification.new do |spec|
  spec.name          = "smart_enum"
  spec.version       = SmartEnum::VERSION
  spec.authors       = ["Carl Brasic", "Joshua Flanagan"]
  spec.email         = ["cbrasic@gmail.com", "joshuaflanagan@gmail.com"]

  spec.summary       = %q{Enums to replace database lookup tables}
  spec.description   = %q{Enums to replace database lookup tables}
  spec.homepage      = "https://github.com/ShippingEasy/smart_enum"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*", "Rakefile", "README.md", "LICENSE.txt", "smart_enum.gemspec"]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  # needed to run test suite for optional features, but consumers don't need it
  spec.match_shipit_version "activerecord", development: true
  spec.add_development_dependency "money"
end
