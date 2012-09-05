require "test_helper"
require "transaction_retry"

describe TransactionRetry do
  before do
    @connection = mock()
    @connection.singleton_class.class_exec do
      attr_accessor :open_transactions
    end
    @connection.open_transactions = 0
    @buffer = StringIO.new
    @logger = Logger.new(@buffer)
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
      /sleep then reconnect then retry/ => [:sleep, :reconnect, :retry],
      /sleep then retry/ => [:sleep, :retry],
      /reconnect then retry/ => [:reconnect, :retry],
      /retry/ => :retry
    }
  end

  it "should work with no errors" do
    @mock.transaction { :success }.must_equal(:success)
  end

  it "should work with less or equal errors than retries" do
    errors = ["sleep then retry", "retry"]
    @mock.transaction_retries = [0] * errors.size
    @mock.transaction { errors.any? ? raise(ActiveRecord::StatementInvalid, errors.shift) : :success }.must_equal(:success)
  end

  it "should not work with more errors than retries" do
    errors = ["sleep then retry", "retry", "retry"]
    @mock.transaction_retries = [0] * (errors.size - 1)
    -> { @mock.transaction { errors.any? ? raise(ActiveRecord::StatementInvalid, errors.shift) : :success } }.must_raise(ActiveRecord::StatementInvalid)
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

  it "logs a warning when a transaction is being retried that describes what it is doing" do
    @mock.transaction_retries = [2]

    -> do
      @mock.transaction do
        raise ActiveRecord::StatementInvalid, "sleep then reconnect then retry"
      end
    end.must_raise(ActiveRecord::StatementInvalid)

    warning = @buffer.string
    warning.wont_be_empty
    /sleeping for 2s/i.must_match(warning)
    /reconnecting/i.must_match(warning)
    /retrying/i.must_match(warning)
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
