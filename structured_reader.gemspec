# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "structured_reader/version"

Gem::Specification.new do |spec|
  spec.name          = "structured_reader"
  spec.version       = StructuredReader::VERSION
  spec.authors       = ["Matthew Boeh"]
  spec.email         = ["m@mboeh.com"]

  spec.summary       = %q{Read primitive and JSON data structures into data objects}
  spec.description   = %q{This library allows you to create declarative rulesets (or schemas) for reading primitive data structures (hashes + arrays + strings + numbers) or JSON into validated data objects.}
  spec.homepage      = "https://github.com/mboeh/structured_reader"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
