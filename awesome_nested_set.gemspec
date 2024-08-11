# frozen_string_literal: true

require File.expand_path('lib/awesome_nested_set/version', __dir__)

Gem::Specification.new do |s|
  s.name = 'awesome_nested_set'
  s.version = ::AwesomeNestedSet::VERSION
  s.authors = ['Brandon Keepers', 'Daniel Morrison', 'Philip Arndt']
  s.description = 'An awesome nested set implementation for Active Record'
  s.email = 'info@collectiveidea.com'
  s.extra_rdoc_files = %w[README.md]
  s.files = Dir.glob('lib/**/*') + %w[MIT-LICENSE README.md CHANGELOG]
  s.homepage = 'https://github.com/collectiveidea/awesome_nested_set'
  s.rdoc_options = ['--main', 'README.md', '--inline-source', '--line-numbers']
  s.require_paths = ['lib']
  s.summary = 'An awesome nested set implementation for Active Record'
  s.license = 'MIT'

  s.required_ruby_version = '>= 2.0.0'

  s.add_runtime_dependency 'activerecord', '>= 4.0.0', '< 8.0'

  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-nav'
  s.add_development_dependency 'rake', '~> 13'
  s.add_development_dependency 'rspec-rails', '~> 4.0.0'
end
