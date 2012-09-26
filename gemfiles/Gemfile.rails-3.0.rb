source :rubygems

gemspec :path => '../'

platforms :jruby do
  gem 'activerecord-jdbcsqlite3-adapter'
  gem 'activerecord-jdbcmysql-adapter'
  gem 'activerecord-jdbcpostgresql-adapter'
  gem 'jruby-openssl'
end

platforms :ruby do
  gem 'sqlite3'
  gem 'mysql2', '~> 0.2.0'
  gem 'pg'
end

gem 'activerecord', '~> 3.0.0'
