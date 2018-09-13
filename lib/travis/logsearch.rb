# frozen_string_literal: true

# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
# LOGS_S3_BUCKET
# LOGS_API_URL, LOGS_API_AUTH_TOKEN
# DATABASE_URL
# ELASTICSEARCH_URL || BONSAI_URL
# REDIS_URL

require 'redis-namespace'
require 'travis/logsearch/model'
require 'travis/logsearch/ingester'
require 'travis/logsearch/worker'

module Travis
  module LogSearch
    def self.setup
      ActiveRecord::Base.establish_connection(
        url:  ENV['DATABASE_URL'],
        pool: ENV['DB_POOL']&.to_i || ENV['SIDEKIQ_THREADS']&.to_i,
      )
      ActiveRecord::Base.logger = Logger.new(STDOUT) if ENV['DEBUG'] == 'true'

      redis = { url: ENV['REDIS_URL'], namespace: 'sidekiq' }
      ::Sidekiq.configure_server { |c| c.redis = redis }
      ::Sidekiq.configure_client { |c| c.redis = redis }
    end

    def self.run
      setup
      ingester.run(id)
    end

    def self.ingester
      Thread.current[:ingester] ||= Ingester.new
    end
  end
end
