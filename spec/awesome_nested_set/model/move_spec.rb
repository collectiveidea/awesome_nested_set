require 'spec_helper'

describe "AwesomeNestedSet" do
  before(:all) do
    self.class.fixtures :users, :categories
  end

  after(:all) do
    SQLCounter.clear_log
  end

  describe "move" do
    it 'lock_nodes_between sql' do
      parent = User.first

      sql = 'SELECT "users"."uuid" FROM "users" WHERE "users"."name" = ? AND "users"."lft" >= 10 AND "users"."rgt" <= 14'
      assert_sql(sql) do
        User.where(name: "Chris-#{Time.current.to_f}").first_or_create! do |user|
          user.parent = parent
        end
      end
    end
  end

  describe "scoping" do
    it 'scoped sql' do

      sql = 'SELECT "categories".* FROM "categories" WHERE "categories"."organization_id" = ? AND "categories"."parent_id" IS NULL ORDER BY "categories"."lft" ASC LIMIT ?'
      assert_sql(sql) do
        ScopedCategory.where(organization_id: 1).root
      end
    end
  end

  def capture_sql
    ActiveRecord::Base.connection.materialize_transactions if Rails::VERSION::MAJOR > 5
    SQLCounter.clear_log
    yield
    SQLCounter.log.dup
  end

  def assert_sql(*patterns_to_match)
    capture_sql { yield }
  ensure
    failed_patterns = []
    patterns_to_match.each do |pattern|
      failed_patterns << pattern unless SQLCounter.log_all.any? { |sql| pattern === sql }
    end
    assert failed_patterns.empty?, "Query pattern(s) #{failed_patterns.map(&:strip).join(', ')} not found.#{SQLCounter.log.size == 0 ? '' : "\nQueries:\n#{SQLCounter.log.map(&:inspect).join("\n")}"}"
  end

  class SQLCounter
    class << self
      attr_accessor :ignored_sql, :log, :log_all
      def clear_log; self.log = []; self.log_all = []; end
    end

    clear_log

    def call(name, start, finish, message_id, values)
      return if values[:cached]

      sql = values[:sql].squish
      self.class.log_all << sql
      self.class.log << sql unless ["SCHEMA", "TRANSACTION"].include? values[:name]
    end
  end

  ActiveSupport::Notifications.subscribe("sql.active_record", SQLCounter.new)

end
