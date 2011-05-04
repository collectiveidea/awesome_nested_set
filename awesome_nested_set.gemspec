# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'awesome_nested_set/version'

Gem::Specification.new do |s|
  s.name = %q{awesome_nested_set}
  s.version = ::AwesomeNestedSet::VERSION
  s.authors = ["Brandon Keepers", "Daniel Morrison"]
  s.description = %q{An awesome nested set implementation for Active Record}
  s.email = %q{info@collectiveidea.com}
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = Dir.glob("lib/**/*") + %w(MIT-LICENSE README)
  s.homepage = %q{http://github.com/collectiveidea/awesome_nested_set}
  s.rdoc_options = ["--main", "README.rdoc", "--inline-source", "--line-numbers"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{An awesome nested set implementation for Active Record}
  s.test_files = [
    "test/db/database.yml",
     "test/fixtures/categories.yml",
     "test/fixtures/departments.yml",
     "test/fixtures/notes.yml",
     "test/application.rb",
     "test/awesome_nested_set/helper_test.rb",
     "test/awesome_nested_set_test.rb",
     "test/db/schema.rb",
     "test/fixtures/category.rb",
     "test/test_helper.rb"
  ]

  s.add_runtime_dependency 'activerecord', '>= 3.0.0'
end
