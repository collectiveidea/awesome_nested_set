ENV["RAILS_ENV"] = "test"
plugin_spec_dir = File.dirname(__FILE__)
require File.expand_path(File.dirname(__FILE__) + "/../../../../config/environment")
require 'spec/rails'

ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

databases = YAML::load(IO.read(plugin_spec_dir + "/db/database.yml"))
ActiveRecord::Base.establish_connection(databases[ENV["DB"] || "sqlite3"])
ActiveRecord::Migration.verbose = false
load(File.join(plugin_spec_dir, "db", "schema.rb"))

Spec::Runner.configure do |config|
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false
  config.fixture_path = plugin_spec_dir + '/fixtures'
end

# Rails resoure loading (models, controllers, routes).
Dir["#{plugin_spec_dir}/fixtures/*.rb"].each {|file| require file }
