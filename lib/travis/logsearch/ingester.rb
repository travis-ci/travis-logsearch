# frozen_string_literal: true

require 'aws-sdk'
require 'elasticsearch'
require 'json'
require 'securerandom'
require 'faraday'

module Travis
  module LogSearch
    class Ingester
      def run(job_id)
        job = Job.includes(:config).includes(:repository).find(job_id)
        docs = process_jobs([job])
        send_to_elasticsearch(docs)
      end

      def send_to_elasticsearch(docs)
        docs.each do |doc|
          es.create(
            index: es_index_name,
            type: 'doc',
            body: doc,
          )
        end
      end

      # create one index per day (so that we can manage retention)
      # prefix the index name with `events-` so that it matches the
      # auto-create patterns on bonsai elasticsearch
      def es_index_name
        'events-' + DateTime.now.strftime('%Y_%m_%d')
      end

      def process_jobs(jobs)
        docs = []
        jobs.each do |job|
          begin
            docs << process_job(job)
          rescue => e
            raise
            puts "error: #{e.class}: #{e}"
          end
        end
        docs
      end

      def process_job(job)
        id = job.id

        # try s3 first to avoid call against logs api
        # try s3 again in the end in case log was archived in between the two calls
        log = get_log_from_s3(id) || get_log_from_logs_api(id) || get_log_from_s3(id)

        unless log
          puts "Warning: no log found for job id=#{id} repo=#{job.repository&.slug}"
        end

        doc = {
          job_id: id,
          log: log ? clear_ansi(log) : nil,
          repository_id: job.repository_id,
          queue: job.queue,
          state: job.state,
          created_at: job.created_at,
          started_at: job.started_at,
          finished_at: job.finished_at,
          canceled_at: job.canceled_at,
          repo_slug: job.repository&.slug,
          raw_config: job.config&.config.to_json,
          config: job.config&.normalized,
        }
      end

      def get_log_from_s3(id)
        key = "jobs/#{id}/log.txt"
        begin
          obj = s3.get_object(
            bucket: ENV['LOGS_S3_BUCKET'],
            key: key,
          )
          obj.body.read
        rescue Aws::S3::Errors::NoSuchKey => e
          nil
        end
      end

      def get_log_from_logs_api(id)
        resp = logs_conn.get do |req|
          req.url "logs/#{id}", by: 'job_id'
          req.params['source'] = 'logsearch'
        end
        return nil unless resp.success?
        data = JSON.parse(resp.body)
        data['content']
      end

      def clear_ansi(content)
        content.gsub(/\r\r/, "\r")
               .gsub(/^.*\r(?!$)/, '')
               .gsub(/\x1b(\[|\(|\))[;?0-9]*[0-9A-Za-z]/m, '')
      end

      def logs_conn
        @logs_conn ||= Faraday.new(url: ENV['LOGS_API_URL']) do |c|
          c.request :authorization, :token, ENV['LOGS_API_AUTH_TOKEN']
          c.request :retry, max: 5, interval: 0.1, backoff_factor: 2
          c.adapter :net_http_persistent
        end
      end

      def s3
        @s3 ||= Aws::S3::Client.new
      end

      def es
        @es ||= Elasticsearch::Client.new(
          url: config.elasticsearch.url,
          log: config.debug,
        )
      end

      def config
        Travis::LogSearch.config
      end
    end
  end
end
