plugin_test_dir = File.dirname(__FILE__)

require 'rubygems'
require 'bundler/setup'
require 'pry'

require 'logger'
require 'active_record'
ActiveRecord::Base.logger = Logger.new(plugin_test_dir + "/debug.log")

require 'yaml'
require 'erb'
ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read(plugin_test_dir + "/db/database.yml")).result)
ActiveRecord::Base.establish_connection((ENV["DB"] ||= "sqlite3mem").to_sym)
ActiveRecord::Migration.verbose = false

require 'combustion/database'
Combustion::Database.create_database(ActiveRecord::Base.configurations[ENV["DB"]])
load(File.join(plugin_test_dir, "db", "schema.rb"))

require 'awesome_nested_set'
require 'support/models'

begin
  require 'action_view'
rescue LoadError; end # action_view doesn't exist in Rails 4.0, but we need this for the tests to run with Rails 4.1

require 'action_controller'
require 'rspec/rails'
require 'database_cleaner'
RSpec.configure do |config|
  config.fixture_path = "#{plugin_test_dir}/fixtures"
  config.use_transactional_fixtures = true
  config.after(:suite) do
    unless /sqlite/ === ENV['DB']
      Combustion::Database.drop_database(ActiveRecord::Base.configurations[ENV['DB']])
    end
  end
end
