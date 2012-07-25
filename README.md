# transaction-retry

transaction-retry retries `ActiveRecord` transactions on specific errors.

## Description

Retries transactions when an `ActiveRecord::StatementInvalid` occurs that matches a list of errors.

## Installation

If you're using rails, add this line your application's Gemfile:

    gem "transaction-retry", require: "transaction_retry/railtie"

Otherwise add this line to your application's Gemfile:

    gem "transaction-retry"

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install transaction-retry

## Usage

```ruby
require "active_record"
require "transaction_retry"

ActiveRecord::Base.send(:include, TransactionRetry)
ActiveRecord::Base.transaction_retries = [2, 4, 8, 16]

ActiveRecord::Base.establish_connection(...)
ActiveRecord::Base.transaction do
  ActiveRecord::Base.execute(...) # Oh noes, server went away but that's okay since we'll retry 4 times over 30 seconds
end
```

## Contributing

Fork, branch & pull request.
