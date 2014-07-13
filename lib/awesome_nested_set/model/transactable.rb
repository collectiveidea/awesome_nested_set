module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      module Model
        module Transactable
          class OpenTransactionsIsNotZero < ActiveRecord::StatementInvalid
          end

          class DeadlockDetected < ActiveRecord::StatementInvalid
          end

          protected
          def in_tenacious_transaction(&block)
            retry_count = 0
            begin
              transaction(&block)
            rescue ActiveRecord::StatementInvalid => error
              raise OpenTransactionsIsNotZero.new(error.message) unless connection.open_transactions.zero?
              raise unless error.message =~ /Deadlock found when trying to get lock|Lock wait timeout exceeded/
              raise DeadlockDetected.new(error.message) unless retry_count < 10
              retry_count += 1
              logger.info "Deadlock detected on retry #{retry_count}, restarting transaction"
              sleep(rand(retry_count)*0.1) # Aloha protocol
              retry
            end
          end

        end
      end
    end
  end
end
