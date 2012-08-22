require File.expand_path("../.gemspec", __FILE__)
require File.expand_path("../lib/transaction_retry/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "transaction-retry"
  gem.authors     = ["Samuel Kadolph"]
  gem.email       = ["samuel@kadolph.com"]
  gem.description = readme.description
  gem.summary     = readme.summary
  gem.homepage    = "http://samuelkadolph.github.com/transaction-retry/"
  gem.version     = TransactionRetry::VERSION

  gem.files       = Dir["lib/**/*"]
  gem.test_files  = Dir["test/**/*_test.rb"]

  gem.required_ruby_version = ">= 1.9.2"

  gem.add_dependency "activerecord", "~> 3.0"
  gem.add_dependency "activesupport", "~> 3.0"

  gem.add_development_dependency "bundler", "~> 1.1.5"
  gem.add_development_dependency "mocha", "~> 0.12.1"
  gem.add_development_dependency "rake", "~> 0.9.2.2"
end
