require "active_record"
require "active_record/errors"
require "active_support/concern"
require "active_support/core_ext/integer/inflections"
require "active_support/core_ext/module/attribute_accessors"

module ActiveRecord
  module Retry
    require "active_record/retry/version"

    extend ActiveSupport::Concern

    DEFAULT_RETRIES = [1, 2, 4].freeze
    DEFAULT_RETRY_ERRORS = {
      # MySQL errors
      /Deadlock found when trying to get lock/ => :retry,
      /Lock wait timeout exceeded/ => :retry,
      /Lost connection to MySQL server during query/ => [:sleep, :reconnect, :retry],
      /MySQL server has gone away/ => [:sleep, :reconnect, :retry],
      /Query execution was interrupted/ => :retry,
      /The MySQL server is running with the --read-only option so it cannot execute this statement/ => [:sleep, :reconnect, :retry]
    }.freeze

    included do
      mattr_accessor :retry_errors, :retries

      self.retries = self::DEFAULT_RETRIES.dup
      self.retry_errors = self::DEFAULT_RETRY_ERRORS.dup

      class << self
        alias_method :find_by_sql_without_retry, :find_by_sql
        alias_method :find_by_sql, :find_by_sql_with_retry
        alias_method :transaction_without_retry, :transaction
        alias_method :transaction, :transaction_with_retry
      end
    end

    module ClassMethods
      def find_by_sql_with_retry(*args, &block)
        with_retry { find_by_sql_without_retry(*args, &block) }
      end

      def transaction_with_retry(*args, &block)
        with_retry { transaction_without_retry(*args, &block) }
      end

      def with_retry
        tries = 0

        begin
          yield
        rescue ActiveRecord::StatementInvalid => error
          raise if connection.open_transactions != 0
          raise if tries >= retries.count

          found, actions = retry_errors.detect { |regex, action| regex =~ error.message }
          raise unless found

          actions = Array(actions)
          delay = retries[tries]
          tries += 1

          if logger
            message = "Query failed: '#{error}'. "
            message << actions.map do |action|
              case action
              when :sleep
                "sleeping for #{delay}s"
              when :reconnect
                "reconnecting"
              when :retry
                "retrying"
              end
            end.join(", ").capitalize
            message << " for the #{tries.ordinalize} time."
            logger.warn(message)
          end

          sleep(delay) if actions.include?(:sleep)
          if actions.include?(:reconnect)
            clear_active_connections!
            establish_connection
          end
          retry if actions.include?(:retry)
        end
      end
    end
  end
end
