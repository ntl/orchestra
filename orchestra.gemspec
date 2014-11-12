# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'orchestra/version'

Gem::Specification.new do |spec|
  spec.name          = "orchestra"
  spec.version       = Orchestra::VERSION
  spec.authors       = ["ntl"]
  spec.email         = ["nathanladd+github@gmail.com"]
  spec.summary       = %q{Orchestrate complex operations with ease.}
  spec.description   = %q{Orchestra is an orchestration framework for designing complex operations in an object oriented fashion.}
  spec.homepage      = "https://github.com/ntl/orchestra"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = []
  spec.test_files    = spec.files.grep(%r{^test/})
  spec.require_paths = %w(lib)

  spec.add_dependency "invokr"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~> 10.0"
end
