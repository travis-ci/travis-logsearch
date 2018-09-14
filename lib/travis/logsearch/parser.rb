# frozen_string_literal: true

module Travis
  module LogSearch
    ALIASES = {}

    class Parser
      def folds(nodes)
        nodes
          .select { |n| n[:type] == :fold }
          .reject { |n| n[:name] =~ /^fold-[0-9a-f]{8}$/ }
          .reject { |n| n[:name] =~ /^test_project_[0-9]+$/ }
          .reject { |n| n[:name] =~ /^[0-9]+$/ }
          .reject { |n| n[:name] =~ /^test./ }
          .reject { |n| n[:name] =~ /^Simple$/ }
          .map { |n|
            name = n[:name]
            name = ALIASES[name] if ALIASES[name]
            name = name.gsub(/\.[0-9]+$/, '')

            body = n[:body].strip

            [name, body]
          }
          .group_by { |kv| kv[0] }
          .map { |name, kvs| [name, kvs.map { |kv| kv[1] }.join("\n\n")] }
          .to_h
          .tap { |h|
            h.delete('system_info');
            h.delete('rvm');
            h.delete('ruby.versions')
          }
      end

      def text(nodes)
        nodes
          .select { |n| n[:type] == :text }
          .map { |n| n[:body].strip }
          .join("\n\n")
      end

      def parse(log)
        log
          .scan(/(?:travis_fold:start:(.+?)\r(.+?)travis_fold:end:(.+?)|(.+?)(?=travis_fold:start|\z))/m)
          .map { |m|
            if m[0]
              { type: :fold, name: m[0], body: m[1] }
            else
              { type: :text, body: m[3] }
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
