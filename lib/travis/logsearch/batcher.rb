# frozen_string_literal: true

require 'thread'
require 'concurrent'

module Travis
  module LogSearch
    class Batcher
      def initialize(batch_size: 10)
        @batch_size = batch_size
        @queue = SizedQueue.new(1)
        @buffer = []
      end

      def index(doc)
        puts "index"
        p = Concurrent::Future.execute {
          puts "write to queue"
          @queue << [doc, p]
          puts "write to queue done"
        }
        p.wait!
        p.value
      end

      def start_flush_thread
        puts "starting flush thread"
        Thread.abort_on_exception = true
        Thread.new {
          loop do
            while @buffer.size < @batch_size
              puts "poll"
              @buffer << @queue.pop
              puts "polled"
            end
            puts "flush"
            flush
          end
        }
      end

      def flush
        body = @buffer.map do |doc, p|
          { create: { _index: es_index_name, _type: 'doc', _id: SecureRandom.hex, data: doc } }
        end
        @buffer = []

        puts "bulk"

        response = es.bulk(body: body)

        puts response
      end

      def config
        Travis::LogSearch.config
      end
    end
  end
end
