#!/usr/bin/env rake

require 'bundler/gem_helper'
require 'rspec/core/rake_task'
require 'appraisal'

Bundler::GemHelper.install_tasks(name: 'awesome_nested_set')

RSpec::Core::RakeTask.new(:spec)

task default: :spec
