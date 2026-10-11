require "rails_helper"
require "rake"

RSpec.describe "admin:grant" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:task) { Rake::Task["admin:grant"] }

  before { task.reenable }

  def run_task(uid)
    task.invoke(uid)
  end

  it "GitHub の数値 ID（uid）が一致するユーザーを管理者にする" do
    user = create(:user, provider: "github", uid: "583231", name: "octocat")

    expect { run_task("583231") }.to output(/octocat（uid: 583231）を管理者にしました/).to_stdout
    expect(user.reload).to be_admin
  end

  it "name が同じでも uid が違う別人は管理者にしない" do
    impostor = create(:user, provider: "github", uid: "999", name: "octocat")

    expect { run_task("583231") }.to raise_error(SystemExit).and output(/まだログインしていません/).to_stderr
    expect(impostor.reload).not_to be_admin
  end

  it "すでに管理者なら何もしない" do
    user = create(:user, :admin, provider: "github", uid: "583231", name: "octocat")

    expect { run_task("583231") }.to output(/すでに管理者です/).to_stdout
    expect(user.reload).to be_admin
  end

  it "GitHub 以外の provider は対象にしない" do
    user = create(:user, provider: "demo", uid: "583231", name: "octocat")

    expect { run_task("583231") }.to raise_error(SystemExit).and output(/まだログインしていません/).to_stderr
    expect(user.reload).not_to be_admin
  end

  it "数値以外（ユーザー名など）が渡されたらエラーで終了する" do
    create(:user, provider: "github", uid: "583231", name: "octocat")

    expect { run_task("octocat") }.to raise_error(SystemExit).and output(/数値 ID を指定してください/).to_stderr
  end

  it "引数が空ならエラーで終了する" do
    expect { run_task("") }.to raise_error(SystemExit).and output(/数値 ID を指定してください/).to_stderr
  end
end
