# GitHub OAuth。クライアント ID と secret は環境変数で渡す
# （検証環境の STAGING_BASIC_AUTH_PASSWORD と同じく、Kamal の secrets から注入する）。
# 未設定の development では開発用ログイン（/login のユーザー切り替え）を使う。
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github, ENV["GITHUB_CLIENT_ID"], ENV["GITHUB_CLIENT_SECRET"], scope: ""
end

# omniauth-rails_csrf_protection が POST のみに制限する。GET の /auth/github は
# CSRF で他サイトからログインさせられるため、ここでも明示して戻らないようにする
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.logger = Rails.logger
