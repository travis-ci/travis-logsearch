# frozen_string_literal: true

require 'sidekiq'

module Travis
  module LogSearch
    class Worker
      include Sidekiq::Worker

      def perform(job_id)
        Travis::LogSearch.ingester.run(job_id)
      end
    end
  end
end
