require "test_helper"
require "transaction_retry"

class Moch
  class << self
    def connection
      MiniTest::Mock.new.tap do |mock|
        mock.expect(:open_transactions, 0)
      end
    end

    def transaction
      yield
    end
  end

  include TransactionRetry
end

describe TransactionRetry do
  it "should not retry more than retries count" do
    retries = Moch.transaction_retries = [0]
    runs = 0

    Moch.transaction do
      runs += 1
      raise ActiveRecord::StatementInvalid, "Lost connection to MySQL server during query"
    end

    runs.must_equal(retries.count)
  end
end
