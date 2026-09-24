# GitHub OAuth を入れるまでは開発用ログインでセッションを作る。
# 認証を実装したらここを差し替える。
module Authentication
  def sign_in(user)
    post dev_sessions_path(user_id: user.id)
  end
end

RSpec.configure do |config|
  config.include Authentication, type: :request
end
