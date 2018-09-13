require 'travis/config'

module Travis
  module LogSearch
    class Config < Travis::Config
      define database: { adapter: 'postgresql', encoding: 'unicode', min_messages: 'warning', pool: 10, variables: { statement_timeout: 1_000, application_name: 'logsearch' } },
             redis:    { url: 'redis://localhost:6379' },
             sidekiq:  { namespace: 'sidekiq', log_level: :info },
             elasticsearch: { url: ENV['ELASTICSEARCH_URL'] || ENV['BONSAI_URL'] },
             logger:   { level: :info },
             metrics:  { reporter: 'librato', librato: { email: 'metrics@email.com', token: 'token' } },
             site:     ENV['TRAVIS_SITE'],
             debug:    ENV['DEBUG'] == 'true'
    end
  end
end
