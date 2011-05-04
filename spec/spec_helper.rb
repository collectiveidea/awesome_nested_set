$:.unshift(File.dirname(__FILE__) + '/../lib')
plugin_test_dir = File.dirname(__FILE__)

require 'rubygems'
require 'bundler/setup'

require 'rspec'
require 'logger'

require 'active_support'
require 'active_model'
require 'active_record'
require 'action_controller'
require 'factory_girl'
require 'database_cleaner'
require 'ruby-debug'

require 'awesome_nested_set'

ActiveRecord::Base.logger = Logger.new(plugin_test_dir + "/debug.log")

ActiveRecord::Base.configurations = YAML::load(IO.read(plugin_test_dir + "/db/database.yml"))
ActiveRecord::Base.establish_connection(ENV["DB"] || "sqlite3mem")
ActiveRecord::Migration.verbose = false
load(File.join(plugin_test_dir, "db", "schema.rb"))

require 'support/models'

require 'rspec/rails'
RSpec.configure do |config|
  config.fixture_path = "#{plugin_test_dir}/fixtures"
  config.use_transactional_fixtures = true
end
