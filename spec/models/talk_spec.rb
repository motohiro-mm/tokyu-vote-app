require "rails_helper"

RSpec.describe Talk do
  it "votable は発表予定のものだけを返す" do
    event = create(:event)
    scheduled = create(:talk, event: event)
    create(:talk, event: event, status: :canceled)

    expect(event.talks.votable).to contain_exactly(scheduled)
  end

  it "投票開始後はステータスを変更できない" do
    event = create(:event, status: :preparing)
    talk = create(:talk, event: event)

    expect(talk.update(status: :canceled)).to be true

    event.open!
    expect(talk.reload.update(status: :scheduled)).to be false
    expect(talk.errors[:status]).to include("は投票開始後には変更できません")
  end

  it "投票開始後でもステータス以外は変更できる" do
    event = create(:event, status: :open)
    talk = create(:talk, event: event)

    expect(talk.update(title: "差し替え後のタイトル")).to be true
  end
end
