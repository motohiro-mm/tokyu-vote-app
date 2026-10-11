require "rails_helper"
require "rake"

RSpec.describe "admin:grant" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:task) { Rake::Task["admin:grant"] }

  before { task.reenable }

  def run_task(login)
    task.invoke(login)
  end

  # GitHub API は叩かず、ログイン名 → uid の解決だけを差し替える
  def github_resolves(login, to:)
    allow(GithubAccount).to receive(:uid_for).with(login).and_return(to)
  end

  it "GitHub の数値 ID（uid）が一致するユーザーを管理者にする" do
    user = create(:user, provider: "github", uid: "583231", name: "octocat")
    github_resolves("octocat", to: "583231")

    expect { run_task("octocat") }.to output(/octocat（uid: 583231）を管理者にしました/).to_stdout
    expect(user.reload).to be_admin
  end

  it "改名してログイン名が変わっていても uid で見つける" do
    user = create(:user, provider: "github", uid: "583231", name: "old-name")
    github_resolves("octocat", to: "583231")

    expect { run_task("octocat") }.to output(/old-name（uid: 583231）を管理者にしました/).to_stdout
    expect(user.reload).to be_admin
  end

  it "name が一致しても uid が違う別人は管理者にしない" do
    impostor = create(:user, provider: "github", uid: "999", name: "octocat")
    github_resolves("octocat", to: "583231")

    expect { run_task("octocat") }.to raise_error(SystemExit).and output(/まだログインしていません/).to_stderr
    expect(impostor.reload).not_to be_admin
  end

  it "すでに管理者なら何もしない" do
    user = create(:user, :admin, provider: "github", uid: "583231", name: "octocat")
    github_resolves("octocat", to: "583231")

    expect { run_task("octocat") }.to output(/すでに管理者です/).to_stdout
    expect(user.reload).to be_admin
  end

  it "GitHub に存在しないログイン名ならエラーで終了する" do
    github_resolves("nobody", to: nil)

    expect { run_task("nobody") }.to raise_error(SystemExit).and output(/GitHub に存在しません/).to_stderr
  end

  it "GitHub API を確認できなければエラーで終了し、誰も変更しない" do
    user = create(:user, provider: "github", uid: "583231", name: "octocat")
    allow(GithubAccount).to receive(:uid_for).and_raise(GithubAccount::LookupError, "GitHub API が 503 を返しました")

    expect { run_task("octocat") }.to raise_error(SystemExit).and output(/確認できませんでした.*503/).to_stderr
    expect(user.reload).not_to be_admin
  end

  it "GitHub 以外の provider は対象にしない" do
    user = create(:user, provider: "demo", uid: "583231", name: "octocat")
    github_resolves("octocat", to: "583231")

    expect { run_task("octocat") }.to raise_error(SystemExit).and output(/まだログインしていません/).to_stderr
    expect(user.reload).not_to be_admin
  end

  it "ユーザー名が空ならエラーで終了する" do
    expect { run_task("") }.to raise_error(SystemExit).and output(/指定してください/).to_stderr
  end
end
