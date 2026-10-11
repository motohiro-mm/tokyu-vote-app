# Be sure to restart your server when you modify this file.

# Content Security Policy。ユーザー入力はすべてエスケープして出しているが、将来エスケープ漏れが
# 起きたときにスクリプトが動かないよう、ブラウザ側でも実行元を制限する。
# https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# importmap は <script type="importmap"> と <script type="module"> をインラインで入れるため、
# script-src は 'self' に加えてリクエストごとの nonce で許可する。importmap-rails と Turbo
# （進捗バーの <style>）は nonce を自動で付けるので、style-src も nonce で許可する。
#
# form-action は入れない。GitHub ログインの POST /auth/github は github.com へリダイレクトし、
# Chrome はリダイレクト先にも form-action を適用するためログインが止まる。
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.connect_src :self
    policy.base_uri    :self
  end

  # セッション ID を nonce にすると同じユーザーのページ間で値が使い回されるため、リクエストごとに生成する
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  # Turbo は進捗バーの <style> に csp-nonce の meta から nonce を付けるので、style-src も nonce で許可する
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  # まずは違反を報告するだけで止めない。staging で画面を一通り確認してから enforce に切り替える
  config.content_security_policy_report_only = true
end
