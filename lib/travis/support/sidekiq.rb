# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/logging'
require 'travis/exceptions/sidekiq'
require 'travis/metrics/sidekiq'

module Travis
  module Sidekiq
    def self.setup(config)
      redis = { url: config.redis.url, namespace: config.sidekiq.namespace }

      ::Sidekiq.configure_server do |c|
        c.redis = redis
        c.server_middleware do |chain|
          chain.add Exceptions::Sidekiq if config.sentry&.dsn
          chain.add Metrics::Sidekiq
        end
        c.logger.level = ::Logger::const_get(config.sidekiq.log_level.upcase.to_s)
      end

      ::Sidekiq.configure_client { |c| c.redis = redis }
    end
  end
end
