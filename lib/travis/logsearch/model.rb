# frozen_string_literal: true

require 'active_record'

module Travis
  module LogSearch
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
  end
end
