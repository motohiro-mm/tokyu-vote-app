# OmniAuth のテストモードで GitHub の応答を差し替え、本番と同じ経路でログインする。
module Authentication
  def sign_in(user)
    mock_github_auth(provider: user.provider, uid: user.uid, nickname: user.name)
    post "/auth/github"
    follow_redirect!
  end

  def mock_github_auth(provider: "github", uid:, nickname:)
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: provider, uid: uid, info: { nickname: nickname }
    )
  end
end

RSpec.configure do |config|
  config.include Authentication, type: :request

  config.before(:suite) do
    OmniAuth.config.test_mode = true
    # ログインのたびに bcrypt を通るため、テストではハッシュのコストを最小にして時間を抑える
    BCrypt::Engine.cost = BCrypt::Engine::MIN_COST
  end
  config.after { OmniAuth.config.mock_auth[:github] = nil }
end
