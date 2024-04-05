Gem::Specification.new do |s|
  s.name          = "lmc-store"
  s.version       = "0.0.1"
  s.summary       = "Rails cache store implementation for LocalMemCache (a modern one)"
  s.authors       = ["Anton Argirov"]
  s.email         = "anton.argirov@gmail.com"
  s.files         = Dir.glob("{lib,spec}/**/*") + %w(Gemfile Rakefile LICENSE.txt lmc-store.gemspec README.md)
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']
  s.homepage      = "https://github.com/anteo/lmc-store"
  s.license       = "MIT"

  s.add_dependency 'activesupport', ['>=0']
  s.add_dependency 'localmemcache', ['~>0.4.0']
end