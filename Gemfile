source 'https://rubygems.org'

gemspec

platforms :jruby do
  rails_version = ENV['RAILS_VERSION'] || ''
  gem 'jruby-openssl'
  if rails_version.match(/5\.\d+\.\d+/)
    gem 'activerecord-jdbcsqlite3-adapter',
        git: 'https://github.com/jruby/activerecord-jdbc-adapter.git',
        branch: 'rails-5'
  else
    gem 'activerecord-jdbcsqlite3-adapter', '>= 1.3.0.beta2'
  end
  gem 'activerecord-jdbcmysql-adapter', '>= 1.3.0.beta2'
  gem 'jdbc-mysql'
  gem 'activerecord-jdbcpostgresql-adapter', '>= 1.3.0.beta2'
end

platforms :ruby do
  gem 'sqlite3'
  gem 'mysql2', "< 0.4.0"
  gem 'pg'
end
