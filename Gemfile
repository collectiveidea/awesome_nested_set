gem 'combustion', :github => 'pat/combustion', :branch => 'master'

source 'https://rubygems.org'

gemspec :path => File.expand_path('../', __FILE__)

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter', '>= 1.3.0.beta2'
  gem 'activerecord-jdbcmysql-adapter', '>= 1.3.0.beta2'
  gem 'jdbc-mysql'
  gem 'activerecord-jdbcpostgresql-adapter', '>= 1.3.0.beta2'
  gem 'jruby-openssl'
end

platforms :ruby do
  gem 'sqlite3'
  gem 'mysql2', (MYSQL2_VERSION if defined? MYSQL2_VERSION)
  gem 'pg'
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubysl-test-unit'
end

# Add Oracle Adapters
# gem 'ruby-oci8'
# gem 'activerecord-oracle_enhanced-adapter'

# Debuggers
gem 'pry'
gem 'pry-nav'
