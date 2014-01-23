# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'term/vt102/version'

Gem::Specification.new do |spec|
  spec.name          = "term-vt102"
  spec.version       = Term::VT102::VERSION
  spec.authors       = ["Mike Owens"]
  spec.email         = ["mike@filespanker.com"]
  spec.summary       = %q{VT102 terminal implementation}
  spec.homepage      = "https://github.com/mieko/term-vt102"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 5.2"
end
