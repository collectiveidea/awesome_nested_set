gem 'combustion', :github => 'pat/combustion'

source 'https://rubygems.org'

gemspec :path => File.expand_path('../', __FILE__)

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'jdbc-mysql'
  gem 'activerecord-jdbcpostgresql-adapter'
  gem 'jruby-openssl'
end

platforms :ruby do
  gem 'sqlite3'
  gem 'mysql2', (MYSQL2_VERSION if defined? MYSQL2_VERSION)
  gem 'pg'
end

gem 'activerecord', :github => 'rails/rails'
gem 'activerecord-deprecated_finders', :github => 'rails/activerecord-deprecated_finders'
gem 'journey', :github => 'rails/journey'

# Add Oracle Adapters
# gem 'ruby-oci8'
# gem 'activerecord-oracle_enhanced-adapter'

# Debuggers
# gem 'pry'
# gem 'pry-nav'
