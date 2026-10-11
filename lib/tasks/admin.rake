# 管理者の付与。本番では管理画面から昇格できる人がまだいない（初回）ことがあるため、
# GitHub Actions の「Grant admin」ワークフローと手元の両方からこのタスクを使う。
namespace :admin do
  desc "GitHub ユーザー名で指定したユーザーを管理者にする（admin:grant[login]）"
  task :grant, [ :login ] => :environment do |_task, args|
    login = args[:login].to_s.strip
    abort "GitHub ユーザー名を指定してください（例: bin/rails \"admin:grant[octocat]\"）" if login.blank?

    # name はログインのたびに GitHub の nickname で更新されるが、改名直後は同名が 2 人いることがありうる
    users = User.where(provider: "github", name: login).order(:id).to_a
    abort "GitHub ユーザー「#{login}」はまだログインしていません。先に一度ログインしてもらってください" if users.empty?
    abort "GitHub ユーザー「#{login}」が複数います（uid: #{users.map(&:uid).join(', ')}）。改名した人に再ログインしてもらってから実行してください" if users.size > 1

    user = users.first
    if user.admin?
      puts "#{user.name} はすでに管理者です"
    else
      user.update!(admin: true)
      puts "#{user.name} を管理者にしました"
    end
  end
end
