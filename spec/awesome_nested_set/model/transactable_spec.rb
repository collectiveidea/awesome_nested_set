require 'spec_helper'
RSpec.configure do |config|
  config.use_transactional_fixtures = false
end

describe "AwesomeNestedSet" do
  
  describe "transactions" do
    it "should retry with sleep on deadlocks or lock wait timeouts" do
      i = 0
      # eg. like a move, where a lock is found
      # in_tenacious_transaction should retry up to 10 times. 4 retries in this example
      DefaultScopedModel.new.send(:in_tenacious_transaction) do
        raise ActiveRecord::StatementInvalid.new('Lock wait timeout exceeded') unless (i+=1) > 3
      end
      expect(i).to eq(4)
    end
  end
end