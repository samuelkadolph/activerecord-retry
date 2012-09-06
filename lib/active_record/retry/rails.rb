require "rails"
require "active_record/retry"

module ActiveRecord
  module Retry
    class Railtie < Rails::Railtie
      config.active_record.retries = ActiveRecord::Retry::DEFAULT_RETRIES

      config.after_initialize do |app|
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.send(:include, ActiveRecord::Retry)
          ActiveRecord::Base.retries = app.config.active_record.retries
        end
      end
    end
  end
end
