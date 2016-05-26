# -*- encoding: utf-8 -*-
require File.expand_path('../lib/awesome_nested_set/version', __FILE__)

Gem::Specification.new do |s|
  s.name = %q{awesome_nested_set}
  s.version = ::AwesomeNestedSet::VERSION
  s.authors = ["Brandon Keepers", "Daniel Morrison", "Philip Arndt"]
  s.description = %q{An awesome nested set implementation for Active Record}
  s.email = %q{info@collectiveidea.com}
  s.extra_rdoc_files = %w[README.md]
  s.files = Dir.glob("lib/**/*") + %w(MIT-LICENSE README.md CHANGELOG)
  s.homepage = %q{http://github.com/collectiveidea/awesome_nested_set}
  s.rdoc_options = ["--main", "README.md", "--inline-source", "--line-numbers"]
  s.require_paths = ["lib"]
  s.summary = %q{An awesome nested set implementation for Active Record}
  s.license = %q{MIT}

  s.required_ruby_version = '>= 2.0.0'

  s.add_runtime_dependency 'activerecord', '5.0.0.rc1'

  s.add_development_dependency 'rspec-rails', '3.5.0.beta3'
  s.add_development_dependency 'rake', '~> 10'
  s.add_development_dependency 'combustion', '>= 0.5.2'
  s.add_development_dependency 'database_cleaner'
end
