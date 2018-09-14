# frozen_string_literal: true

require 'travis/exceptions'
require 'travis/logger'
require 'travis/metrics'
require 'travis/support/database'
require 'travis/support/sidekiq'
require 'travis/logsearch/config'
require 'travis/logsearch/model'
require 'travis/logsearch/parser'
require 'travis/logsearch/batcher'
require 'travis/logsearch/ingester'
require 'travis/logsearch/worker'

module Travis
  module LogSearch
    def self.setup
      Database.setup(config[:database].to_h)
      Exceptions.setup(config, config.env, logger)
      Sidekiq.setup(config)
      @metrics = Metrics.setup(config[:metrics].to_h, logger)

      ingester.start_flush_thread
    end

    def self.ingester
      Thread.current[:ingester] ||= Ingester.new
    end

    def self.logger
      @logger ||= Travis::Logger.new(STDOUT, config)
    end

    def self.config
      @config ||= Config.load
    end
  end
end
