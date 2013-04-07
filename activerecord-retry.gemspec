require File.expand_path("../.gemspec", __FILE__)
require File.expand_path("../lib/active_record/retry/version", __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "activerecord-retry"
  gem.authors     = ["Samuel Kadolph"]
  gem.email       = ["samuel@kadolph.com"]
  gem.description = readme.description
  gem.summary     = readme.summary
  gem.homepage    = "http://samuelkadolph.github.com/activerecord-retry/"
  gem.version     = ActiveRecord::Retry::VERSION

  gem.files       = Dir["lib/**/*"]
  gem.test_files  = Dir["test/**/*_test.rb"]

  gem.required_ruby_version = ">= 1.9.2"

  gem.add_dependency "activerecord", "~> 3.0"
  gem.add_dependency "activesupport", "~> 3.0"

  gem.add_development_dependency "mocha", "~> 0.13.3"
  gem.add_development_dependency "rake", "~> 10.0.4"
end
