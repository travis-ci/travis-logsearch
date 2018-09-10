#!/usr/bin/env ruby
# encoding: UTF-8

require 'active_record'
require 'aws-sdk'
require 'elasticsearch'
require 'json'
require 'securerandom'
require 'faraday'

# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
# LOGS_S3_BUCKET
# LOGS_API_URL, LOGS_API_AUTH_TOKEN
# DATABASE_URL
# ELASTICSEARCH_URL || BONSAI_URL

class JobConfig < ActiveRecord::Base
  def normalized
    config = self.config ? self.config : {}

    {
      sudo: normalize_string(config['sudo']),
      script: normalize_string(config['script']),
    }
  end

  def normalize_string(v)
    return nil if v.nil?
    return v if String === v
    v.inspect
  end
end

class Repository < ActiveRecord::Base
  def slug
    "#{owner_name}/#{name}"
  end
end

class Job < ActiveRecord::Base
  self.inheritance_column = :_type_disabled

  belongs_to :config, foreign_key: :config_id, class_name: 'JobConfig'
  belongs_to :repository
end

class Ingester
  def self.setup
    ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
    ActiveRecord::Base.logger = Logger.new(STDOUT) if ENV['DEBUG'] == 'true'
  end

  def self.run
    setup
    new.run
  end

  def run
    batches.each do |batch|
      docs = process_jobs(batch)
      send_to_elasticsearch(docs)
    end
  end

  def batches
    Job
      .includes(:config)
      .includes(:repository)
      .where("jobs.created_at > now() - interval '10 minutes'")
      .in_batches(of: 20)
  end

  def send_to_elasticsearch(docs)
    body = docs.map do |doc|
      { create: { _index: es_index_name, _type: 'doc', _id: SecureRandom.hex, data: doc } }
    end

    es.bulk body: body
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
    log = get_log_from_s3(id) || get_log_from_logs_api(id)

    doc = {
      log: log,
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
      url: ENV['ELASTICSEARCH_URL'] || ENV['BONSAI_URL'],
      log: ENV['DEBUG'] == 'true',
    )
  end
end

Ingester.run
