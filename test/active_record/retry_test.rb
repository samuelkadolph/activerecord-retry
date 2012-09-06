require "test_helper"
require "active_record/retry"

describe ActiveRecord::Retry do
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
    @mock.stubs(:find_by_sql)
    @mock.stubs(:logger).returns(@logger)
    @mock.stubs(:sleep)
    def @mock.transaction
      connection.open_transactions += 1
      yield
    ensure
      connection.open_transactions -= 1
    end
    @mock.send(:include, ActiveRecord::Retry)
    @mock.retry_errors = {
      /sleep then reconnect then retry/ => [:sleep, :reconnect, :retry],
      /sleep then retry/ => [:sleep, :retry],
      /reconnect then retry/ => [:reconnect, :retry],
      /retry/ => :retry
    }
  end

  it "should work with no errors" do
    @mock.with_retry { :success }.must_equal(:success)
  end

  it "should work with less or equal errors than retries" do
    errors = ["sleep then retry", "retry"]
    @mock.retries = [0, 0]
    @mock.with_retry { errors.any? ? raise(ActiveRecord::StatementInvalid, errors.shift) : :success }.must_equal(:success)
  end

  it "should not work with more errors than retries" do
    errors = ["sleep then retry", "retry", "retry"]
    @mock.retries = [0, 0]
    -> { @mock.with_retry { errors.any? ? raise(ActiveRecord::StatementInvalid, errors.shift) : :success } }.must_raise(ActiveRecord::StatementInvalid)
  end

  it "should not retry more than retries count" do
    retries = @mock.retries = [2, 4, 8, 16]
    runs = 0

    -> do
      @mock.with_retry do
        runs += 1
        raise ActiveRecord::StatementInvalid, "retry"
      end
    end.must_raise(ActiveRecord::StatementInvalid)

    runs.must_equal(1 + retries.count)
  end

  it "should not retry a query inside of a nested transaction" do
    inner_runs = outer_runs = 0

    -> do
      @mock.transaction do
        outer_runs += 1
        @mock.with_retry do
          inner_runs += 1
          raise ActiveRecord::StatementInvalid, "retry"
        end
      end
    end.must_raise(ActiveRecord::StatementInvalid)

    inner_runs.must_equal(outer_runs)
  end

  it "logs a warning when a query is being retried that describes what it is doing" do
    @mock.retries = [2]

    -> do
      @mock.with_retry do
        raise ActiveRecord::StatementInvalid, "sleep then reconnect then retry"
      end
    end.must_raise(ActiveRecord::StatementInvalid)

    warning = @buffer.string
    warning.wont_be_empty
    /sleeping for 2s/i.must_match(warning)
    /reconnecting/i.must_match(warning)
    /retrying/i.must_match(warning)
    /for the 1st time/i.must_match(warning)
  end

  it "sleeps for the proper times" do
    @mock.expects(:sleep).with(2)
    @mock.expects(:sleep).with(4)
    @mock.expects(:sleep).with(8)
    @mock.retries = [2, 4, 8]

    -> do
      @mock.with_retry do
        raise ActiveRecord::StatementInvalid, "sleep then retry"
      end
    end.must_raise(ActiveRecord::StatementInvalid)
  end

  it "clears active connections when action is reconnect" do
    @mock.expects(:clear_active_connections!)
    @mock.expects(:establish_connection)
    @mock.retries = [2]

    -> do
      @mock.with_retry do
        raise ActiveRecord::StatementInvalid, "reconnect then retry"
      end
    end.must_raise(ActiveRecord::StatementInvalid)
  end
end
