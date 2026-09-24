require "rails_helper"

RSpec.describe "投票", type: :request do
  let(:event) { create(:event, status: :open) }
  let(:food) { create(:category, category_name: :food) }
  let(:drink) { create(:category, category_name: :drink) }
  let(:user) { create(:user) }

  def cast(entry, comment: "おいしい")
    post event_votes_path(event), params: { vote: { entry_id: entry.id, comment: comment } }
  end

  before { sign_in(user) }

  it "投票できる" do
    entry = create(:entry, event: event, category: food)

    expect { cast(entry) }.to change(Vote, :count).by(1)
  end

  it "同じエントリーには2回投票できない" do
    entry = create(:entry, event: event, category: food)
    cast(entry)

    expect { cast(entry) }.not_to change(Vote, :count)
    expect(flash[:alert]).to include("同じエントリーには投票できません")
  end

  it "1部門に4票目は投票できない" do
    3.times { cast(create(:entry, event: event, category: food)) }

    expect { cast(create(:entry, event: event, category: food)) }.not_to change(Vote, :count)
    expect(flash[:alert]).to include("3票まで")
  end

  it "票は部門ごとに数える" do
    3.times { cast(create(:entry, event: event, category: food)) }

    expect { cast(create(:entry, event: event, category: drink)) }.to change(Vote, :count).by(1)
  end

  it "締切後は投票できない" do
    entry = create(:entry, event: event, category: food)
    event.counting!

    expect { cast(entry) }.not_to change(Vote, :count)
  end

  it "結果公開後は投票できない" do
    entry = create(:entry, event: event, category: food)
    event.closed!

    expect { cast(entry) }.not_to change(Vote, :count)
  end

  it "ログインしていないと投票できない" do
    entry = create(:entry, event: event, category: food)
    delete logout_path

    expect { cast(entry) }.not_to change(Vote, :count)
    expect(response).to redirect_to login_path
  end
end
