# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'smart_enum/version'

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
  # TODO: move to a development dependency, to make this optional for consumers
  spec.add_dependency "activerecord", "4.2.6"
  # TODO: move to a development dependency, to make this optional for consumers
  spec.add_dependency "money"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
