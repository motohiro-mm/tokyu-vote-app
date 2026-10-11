require "net/http"

# GitHub アカウントの照会。ログイン名（ユーザー名）から、変わらない数値 ID を引く。
# users.uid には omniauth-github が入れる数値 ID（文字列）が入っており、ログイン名は
# 改名・解放・再取得ができるため、権限を付けるときの照合には使わない。
class GithubAccount
  class LookupError < StandardError; end

  API_ENDPOINT = "https://api.github.com/users/"

  # 認証なしの公開 API を使う。管理者付与でしか呼ばないので回数制限（60 回/時）には収まる
  def self.uid_for(login)
    response = Net::HTTP.get_response(URI.join(API_ENDPOINT, login), { "Accept" => "application/vnd.github+json" })

    case response
    when Net::HTTPSuccess then JSON.parse(response.body).fetch("id").to_s
    when Net::HTTPNotFound then nil
    else raise LookupError, "GitHub API が #{response.code} を返しました"
    end
  rescue SocketError, Timeout::Error, OpenSSL::SSL::SSLError => e
    raise LookupError, "GitHub API に接続できませんでした（#{e.message}）"
  end
end
