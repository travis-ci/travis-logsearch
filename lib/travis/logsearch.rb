# frozen_string_literal: true

require 'travis/exceptions'
require 'travis/logger'
require 'travis/metrics'
require 'travis/support/database'
require 'travis/logsearch/model'
require 'travis/logsearch/ingester'
require 'travis/logsearch/worker'
require 'travis/logsearch/worker'

module Travis
  module LogSearch
    def self.setup
      Database.setup(config[:database].to_h)
      Exceptions.setup(config, config.env, logger)
      Sidekiq.setup(config)
      @metrics = Metrics.setup(config[:metrics].to_h, logger)
    end

    def self.ingester
      Thread.current[:ingester] ||= Ingester.new
    end

    def self.config
      @config ||= Config.load
    end
  end
end
