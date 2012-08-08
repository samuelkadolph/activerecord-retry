require "active_record/errors"
require "active_support/concern"
require "active_support/core_ext/integer/inflections"

module TransactionRetry
  require "transaction_retry/version"

  extend ActiveSupport::Concern

  TRANSACTION_RETRY_DEFAULT_RETRIES = [2, 4, 8]
  TRANSACTION_RETRY_ERRORS = {
    /Lost connection to MySQL server during query/ => :reconnect,
    /MySQL server has gone away/ => :reconnect,
    /Query execution was interrupted/ => :retry,
    /The MySQL server is running with the --read-only option so it cannot execute this statement/ => :reconnect
  }

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
        found, action = TRANSACTION_RETRY_ERRORS.detect { |regex, action| regex =~ error.message }
        raise unless found
        raise if connection.open_transactions != 0
        raise if tries >= transaction_retries.count

        delay = transaction_retries[tries]
        tries += 1
        logger.warn("Transaction failed to commit: '#{error.message}'. #{action.to_s.capitalize}ing for the #{tries.ordinalize} time after sleeping for #{delay}s.") if logger
        sleep(delay)

        case action
        when :reconnect
          clear_active_connections!
          establish_connection
          retry
        when :retry
          retry
        end
      end
    end
  end
end
