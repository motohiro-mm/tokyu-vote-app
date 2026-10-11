# 管理者の付与。本番では管理画面から昇格できる人がまだいない（初回）ことがあるため、
# GitHub Actions の「Grant admin」ワークフローと手元の両方からこのタスクを使う。
namespace :admin do
  desc "GitHub ユーザー名で指定したユーザーを管理者にする（admin:grant[login]）"
  task :grant, [ :login ] => :environment do |_task, args|
    login = args[:login].to_s.strip
    abort "GitHub ユーザー名を指定してください（例: bin/rails \"admin:grant[octocat]\"）" if login.blank?

    # users.name は改名・解放・再取得ができるログイン名のスナップショットなので、照合には使わない。
    # GitHub API でログイン名を数値 ID に解決し、変わらない uid で引く
    begin
      uid = GithubAccount.uid_for(login)
    rescue GithubAccount::LookupError => e
      abort "GitHub ユーザー「#{login}」を確認できませんでした: #{e.message}"
    end
    abort "GitHub ユーザー「#{login}」は GitHub に存在しません。綴りを確認してください" if uid.nil?

    user = User.find_by(provider: "github", uid: uid)
    abort "GitHub ユーザー「#{login}」（uid: #{uid}）はまだログインしていません。先に一度ログインしてもらってください" if user.nil?

    if user.admin?
      puts "#{user.name}（uid: #{uid}）はすでに管理者です"
    else
      user.update!(admin: true)
      puts "#{user.name}（uid: #{uid}）を管理者にしました"
    end
  end
end
