require "rails"
require "transaction_retry"

module TransactionRetry
  class Railtie < Rails::Railtie
    config.transaction_retries = TransactionRetry::TRANSACTION_RETRY_DEFAULT_RETRIES

    config.after_initialize do |app|
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.send(:include, TransactionRetry)
        ActiveRecord::Base.transaction_retries = app.config.transaction_retries
      end
    end
  end
end
