require "test_helper"
require "transaction_retry"

class Mock
  class Connection
    attr_accessor :open_transactions
    def initialize
      self.open_transactions = 0
    end
  end

  class << self
    def connection
      return @connection if defined?(@connection)
      @connection = Connection.new
    end

    def clear_active_connections!
    end

    def logger
    end

    def sleep(n)
    end

    def transaction
      connection.open_transactions += 1
      yield
    ensure
      connection.open_transactions -= 1
    end
  end

  include TransactionRetry
end

describe TransactionRetry do
  it "should not retry more than retries count" do
    retries = Mock.transaction_retries = [2, 4, 8, 16]
    runs = 0

    -> do
      Mock.transaction do
        runs += 1
        raise ActiveRecord::StatementInvalid, "Lost connection to MySQL server during query"
      end
    end.must_raise(ActiveRecord::StatementInvalid)

    runs.must_equal(1 + retries.count)
  end

  it "should not retry inside of a nested transaction" do
    inner_runs = outer_runs = 0

    -> do
      Mock.transaction do
        outer_runs += 1
        Mock.transaction do
          inner_runs += 1
          raise ActiveRecord::StatementInvalid, "Lost connection to MySQL server during query"
        end
      end
    end.must_raise(ActiveRecord::StatementInvalid)

    inner_runs.must_equal(outer_runs)
  end

  it "logs a warning when a transaction is being retried" do
    Mock.stubs(:logger).returns(logger = mock())
    Mock.transaction_retries = [2]

    logger.expects(:warn)

    -> do
      Mock.transaction do
        raise ActiveRecord::StatementInvalid, "Lost connection to MySQL server during query"
      end
    end.must_raise(ActiveRecord::StatementInvalid)
  end

  it "sleeps for the proper times" do
    Mock.expects(:sleep).with(2)
    Mock.expects(:sleep).with(4)
    Mock.expects(:sleep).with(8)
    Mock.transaction_retries = [2, 4, 8]

    -> do
      Mock.transaction do
        raise ActiveRecord::StatementInvalid, "Lost connection to MySQL server during query"
      end
    end.must_raise(ActiveRecord::StatementInvalid)
  end
end
