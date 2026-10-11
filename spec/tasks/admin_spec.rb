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

  it "GitHub ユーザー名が一致するユーザーを管理者にする" do
    user = create(:user, provider: "github", name: "octocat")

    expect { run_task("octocat") }.to output(/octocat を管理者にしました/).to_stdout
    expect(user.reload).to be_admin
  end

  it "すでに管理者なら何もしない" do
    user = create(:user, :admin, provider: "github", name: "octocat")

    expect { run_task("octocat") }.to output(/すでに管理者です/).to_stdout
    expect(user.reload).to be_admin
  end

  it "まだログインしていないユーザー名ならエラーで終了する" do
    expect { run_task("nobody") }.to raise_error(SystemExit).and output(/まだログインしていません/).to_stderr
  end

  it "同名のユーザーが複数いるならエラーで終了し、誰も変更しない" do
    users = create_list(:user, 2, provider: "github", name: "octocat")

    expect { run_task("octocat") }.to raise_error(SystemExit).and output(/複数います/).to_stderr
    expect(users.map { |u| u.reload.admin? }).to all(be false)
  end

  it "GitHub 以外の provider は対象にしない" do
    user = create(:user, provider: "demo", name: "octocat")

    expect { run_task("octocat") }.to raise_error(SystemExit).and output(/まだログインしていません/).to_stderr
    expect(user.reload).not_to be_admin
  end

  it "ユーザー名が空ならエラーで終了する" do
    expect { run_task("") }.to raise_error(SystemExit).and output(/指定してください/).to_stderr
  end
end
