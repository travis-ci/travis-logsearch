# frozen_string_literal: true

# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
# LOGS_S3_BUCKET
# LOGS_API_URL, LOGS_API_AUTH_TOKEN
# DATABASE_URL
# ELASTICSEARCH_URL || BONSAI_URL
# REDIS_URL

require 'redis-namespace'
require 'travis/logsearch/config'
require 'travis/logsearch/model'
require 'travis/logsearch/ingester'
require 'travis/logsearch/worker'

module Travis
  module LogSearch
    def self.setup
      ActiveRecord::Base.establish_connection(config[:database].to_h)
      ActiveRecord::Base.logger = Logger.new(STDOUT) if config.debug

      redis = { url: config.redis.url, namespace: config.sidekiq.namespace }
      ::Sidekiq.configure_server { |c| c.redis = redis }
      ::Sidekiq.configure_client { |c| c.redis = redis }
    end

    def self.ingester
      Thread.current[:ingester] ||= Ingester.new
    end

    def self.config
      @config ||= Config.load
    end
  end
end
