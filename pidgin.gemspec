$:.push File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
require 'pidgin/version'

Gem::Specification.new do |s|
  s.name              = 'pidgin'
  s.version           = Pidgin.version
  s.platform          = Gem::Platform::RUBY
  s.author            = 'Michael Williams'
  s.email             = 'm.t.williams@live.com'
  s.summary           = 'Makes building DSLs a cinch!'
  s.description       = 'Pidgin is the swiss army knife for building DSLs.'
  s.license           = 'Public Domain'

  s.required_ruby_version = '>= 1.9.3'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = %w(lib)

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'cucumber'
  s.add_development_dependency 'aruba'
end
