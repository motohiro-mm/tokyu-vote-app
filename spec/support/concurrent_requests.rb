# リクエストスペックのセッションをスレッドごとに分け、同時 POST を再現する。
module ConcurrentRequests
  def post_concurrently(payloads)
    jar = cookies.dup
    ready = Queue.new
    go = Queue.new

    threads = payloads.map do |path, params|
      Thread.new do
        Rails.application.executor.wrap do
          session = ActionDispatch::Integration::Session.new(Rails.application)
          session.host! "www.example.com"
          jar.to_hash.each { |name, value| session.cookies[name] = value }
          ready << true
          go.pop
          session.post(path, params: params)
          session
        end
      end
    end

    payloads.size.times { ready.pop }
    payloads.size.times { go << true }
    threads.map(&:value)
  end
end

RSpec.configure do |config|
  config.include ConcurrentRequests, type: :request
end
