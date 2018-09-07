#!/usr/bin/env ruby
# encoding: UTF-8

require 'elasticsearch'

es = Elasticsearch::Client.new(
  url: ENV['ELASTICSEARCH_URL'] || ENV['BONSAI_URL'],
  log: ENV['DEBUG'] == 'true',
)

es.indices.delete(index: 'jobs')

es.indices.create(
  index: 'jobs',
  body: {
    settings: {
      index: {
        number_of_shards: 5,
        number_of_replicas: 1
      }
    }
  }
)
