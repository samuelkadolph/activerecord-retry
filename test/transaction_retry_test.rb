require "test_helper"
require "transaction_retry"

describe TransactionRetry do
  before do
    @connection = mock()
    @connection.singleton_class.class_exec do
      attr_accessor :open_transactions
    end
    @connection.open_transactions = 0
    @logger = mock()
    @logger.stubs(:warn)
    @mock = Class.new
    @mock.stubs(:connection).returns(@connection)
    @mock.stubs(:clear_active_connections!)
    @mock.stubs(:establish_connection)
    @mock.stubs(:logger).returns(@logger)
    @mock.stubs(:sleep)
    def @mock.transaction
      connection.open_transactions += 1
      yield
    ensure
      connection.open_transactions -= 1
    end
    @mock.send(:include, TransactionRetry)
    @mock.transaction_errors = {
      /sleep then retry/ => [:sleep, :retry],
      /reconnect then retry/ => [:reconnect, :retry],
      /retry/ => :retry
    }
  end

  it "should not retry more than retries count" do
    retries = @mock.transaction_retries = [2, 4, 8, 16]
    runs = 0

    -> do
      @mock.transaction do
        runs += 1
        raise ActiveRecord::StatementInvalid, "retry"
      end
    end.must_raise(ActiveRecord::StatementInvalid)

    runs.must_equal(1 + retries.count)
  end

  it "should not retry inside of a nested transaction" do
    inner_runs = outer_runs = 0

    -> do
      @mock.transaction do
        outer_runs += 1
        @mock.transaction do
          inner_runs += 1
          raise ActiveRecord::StatementInvalid, "retry"
        end
      end
    end.must_raise(ActiveRecord::StatementInvalid)

    inner_runs.must_equal(outer_runs)
  end

  it "logs a warning when a transaction is being retried" do
    @logger.expects(:warn)
    @mock.transaction_retries = [2]

    -> do
      @mock.transaction do
        raise ActiveRecord::StatementInvalid, "retry"
      end
    end.must_raise(ActiveRecord::StatementInvalid)
  end

  it "sleeps for the proper times" do
    @mock.expects(:sleep).with(2)
    @mock.expects(:sleep).with(4)
    @mock.expects(:sleep).with(8)
    @mock.transaction_retries = [2, 4, 8]

    -> do
      @mock.transaction do
        raise ActiveRecord::StatementInvalid, "sleep then retry"
      end
    end.must_raise(ActiveRecord::StatementInvalid)
  end

  it "clears active connections when action is reconnect" do
    @mock.expects(:clear_active_connections!)
    @mock.expects(:establish_connection)
    @mock.transaction_retries = [2]

    -> do
      @mock.transaction do
        raise ActiveRecord::StatementInvalid, "reconnect then retry"
      end
    end.must_raise(ActiveRecord::StatementInvalid)
  end
end
