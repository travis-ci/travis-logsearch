# frozen_string_literal: true

module Travis
  module LogSearch
    ALIASES = %w[
      checkout
      export setup announce
      setup_casher setup_cache
      debug
      before_install install
      before_script script
      after_success after_failure after_script
      before_cache cache reset_state
      before_deploy deploy after_deploy
      before_finish finish
      build cache dpl lint
    ]

    FOLDS_INCLUDE = %w[
      after_deploy.root after_failure.root after_script.root after_success.root
      announce.root folds.apt artifacts.setup
      before_cache.root before_deploy.root before_install.root before_script.root
      cache.bundler cache.cargo cache.ccache cache.pip cache.root cache.yarn ccache.stats
      configure git.checkout
      install.bundler install.deps install.hex install.npm install.rebar install.root
      install.yarn
      services
      step_start_instance step_upload_script
      worker_info
    ]

    FOLDS_DROP = %w[
      system_info rvm ruby.versions
    ]

    class Parser
      def filtered_folds(nodes)
        folds = folds(nodes)
          .reject { |n| FOLDS_DROP.include?(n[:name]) }

        rest = folds
          .reject { |n| FOLDS_INCLUDE.include?(n[:name]) }
          .map { |n| n[:body] }
          .to_h

        folds = folds
          .select { |n| FOLDS_INCLUDE.include?(n[:name]) }
          .map { |n| [n[:name], n[:body]] }
          .to_h

        folds['rest'] = rest.join("\n\n")
        folds
      end

      def folds(nodes)
        nodes
          .select { |n| n[:type] == :fold }
          .group_by { |n| n[:name] }
          .map { |name, nodes|
            name = "#{name}.root" if ALIASES.include?(name)
            [
              name,
              { type: :fold, name: name, body: nodes.map { |n| n[:body] }.join("\n\n") }
            ]
          }
      end

      def text(nodes)
        nodes
          .select { |n| n[:type] == :text }
          .map { |n| n[:body] }
          .join("\n\n")
      end

      def parse(log)
        log
          .scan(/(?:travis_fold:start:(.+?)\r(.+?)travis_fold:end:(.+?)|(.+?)(?=travis_fold:start|\z))/m)
          .map { |m|
            if m[0]
              { type: :fold, name: m[0].strip.gsub(/\.[0-9]+$/, ''), body: m[1].strip }
            else
              { type: :text, body: m[3].strip }
            end
          }
          .map { |n|
            n[:body] = n[:body]
              .gsub(/\r\r/, "\r")
              .gsub(/^.*\r(?!$)/, '')
              .gsub(/\x1b(\[|\(|\))[;?0-9]*[0-9A-Za-z]/m, '')
              .gsub(/\r\n/, "\n")
              .gsub(/\r/, '')
            n
          }
          .select { |n| n[:body] != '' }
      end
    end
  end
end
