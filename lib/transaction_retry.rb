require "active_record/errors"
require "active_support/concern"
require "active_support/core_ext/integer/inflections"

module TransactionRetry
  require "transaction_retry/version"

  extend ActiveSupport::Concern

  TRANSACTION_RETRY_DEFAULT_RETRIES = [1, 2, 4, 8]
  TRANSACTION_RETRY_ERRORS = [
    /Lost connection to MySQL server during query/
  ]

  included do
    mattr_accessor :transaction_retries

    self.transaction_retries = TRANSACTION_RETRY_DEFAULT_RETRIES

    class << self
      alias_method :transaction_without_retry, :transaction
      alias_method :transaction, :transaction_with_retry
    end
  end

  module ClassMethods
    def transaction_with_retry(*args, &block)
      tries = 0

      begin
        transaction_without_retry(*args, &block)
      rescue ActiveRecord::StatementInvalid => error
        raise if TRANSACTION_RETRY_ERRORS.none? { |regex| regex =~ error.message }
        raise if connection.open_transactions != 0
        raise if tries >= transaction_retries.count

        delay = transaction_retry_delays[tries] || 2
        tries += 1
        logger.warn("Transaction failed to commit: '#{error.message}'. Retrying for the #{tries.ordinalize} time after #{delay}s.") if logger
        sleep(delay)
        retry
      end
    end
  end
end
