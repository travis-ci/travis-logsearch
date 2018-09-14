require 'rly'

class LogLex < Rly::Lex
  # token :FOLD, /travis_fold:(start|end):(.+?)\r\\[0K(\[33;1m(.+?)\[0m)?/
  # token :TIME, /travis_time:(start|end):[0-9a-f]{8}(:.+)?/
  token :STR, /(.+)/
end

log = File.read('sample/log.txt')
lex = LogLex.new(log)
while t = lex.next
  puts t.inspect
  puts "-"
end
