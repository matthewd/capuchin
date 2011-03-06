# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capuchin/version"

Gem::Specification.new do |s|
  s.name        = "capuchin"
  s.version     = Capuchin::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Matthew Draper"]
  s.email       = ["matthew@trebex.net"]
  s.homepage    = ""
  s.summary     = %q{JavaScript on Rubinius}
  s.description = %q{A JavaScript implemention on the Rubinus VM.}

  s.add_dependency "parslet", "~> 1.2"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
