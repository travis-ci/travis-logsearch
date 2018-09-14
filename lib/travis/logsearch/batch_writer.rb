# frozen_string_literal: true

require 'elasticsearch'
require 'securerandom'
require 'thread'

module Travis
  module LogSearch
    class BatchWriter
      def initialize
        @buffer = []
        @queue = Queue.new
        @batch_size = config.elasticsearch.batch_size
      end

      def write(doc)
        p = Promises.future(doc)
        @queue << [doc, p]
        p.wait!
      end

      def flush_thread
        Thread.new {
          while buffer.size < @batch_size
            buffer << @queue.pop
          end
        }
      end

      def flush(docs)
        # promises = ...

        body = docs.map do |doc, p|
          { create: { _index: es_index_name, _type: 'doc', _id: SecureRandom.hex, data: doc } }
        end

        response = es.bulk body: body

        # TODO: notify promise

        rescue
          # TODO: fail all promises
      end

      # create one index per day (so that we can manage retention)
      # prefix the index name with `events-` so that it matches the
      # auto-create patterns on bonsai elasticsearch
      def es_index_name
        'events-' + DateTime.now.strftime('%Y_%m_%d')
      end

      def config
        Travis::LogSearch.config
      end
    end
  end
end
