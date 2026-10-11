# 管理者の付与。本番では管理画面から昇格できる人がまだいない（初回）ことがあるため、
# GitHub Actions の「Grant admin」ワークフローと手元の両方からこのタスクを使う。
namespace :admin do
  desc "GitHub の数値 ID（users.uid）で指定したユーザーを管理者にする（admin:grant[uid]）"
  task :grant, [ :uid ] => :environment do |_task, args|
    uid = args[:uid].to_s.strip
    # users.name（GitHub のユーザー名）は改名・解放・再取得ができるため、照合には使わない。
    # ユーザー名から数値 ID への変換は呼び出し側（ワークフローや手元の gh api）で行う
    unless uid.match?(/\A\d+\z/)
      abort "GitHub の数値 ID を指定してください（例: bin/rails \"admin:grant[583231]\"。ID は gh api users/<ユーザー名> --jq .id で調べられます）"
    end

    user = User.find_by(provider: "github", uid: uid)
    abort "GitHub ID #{uid} のユーザーはまだログインしていません。先に一度ログインしてもらってください" if user.nil?

    if user.admin?
      puts "#{user.name}（uid: #{uid}）はすでに管理者です"
    else
      user.update!(admin: true)
      puts "#{user.name}（uid: #{uid}）を管理者にしました"
    end
  end
end
