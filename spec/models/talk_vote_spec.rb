require "rails_helper"

RSpec.describe TalkVote do
  let(:event) { create(:event, status: :open) }
  let(:user) { create(:user) }

  it "同じLTには2票目を投じられない" do
    talk = create(:talk, event: event)
    create(:talk_vote, user: user, talk: talk)

    vote = build(:talk_vote, user: user, talk: talk)

    expect(vote).to be_invalid
    expect(vote.errors[:base]).to include("同じLTには投票できません")
  end

  it "1イベントにつき3票までしか投じられない" do
    3.times { create(:talk_vote, user: user, talk: create(:talk, event: event)) }

    vote = build(:talk_vote, user: user, talk: create(:talk, event: event))

    expect(vote).to be_invalid
    expect(vote.errors[:base]).to include("LT王に投票できるのは3票までです")
  end

  it "票数はイベントごとに数える" do
    3.times { create(:talk_vote, user: user, talk: create(:talk, event: event)) }
    other_talk = create(:talk, event: create(:event))

    expect(build(:talk_vote, user: user, talk: other_talk)).to be_valid
  end

  it "飯王・酒王の票はLT王の票数に数えない" do
    category = create(:category, category_name: :food)
    3.times { create(:vote, user: user, entry: create(:entry, event: event, category: category)) }

    expect(build(:talk_vote, user: user, talk: create(:talk, event: event))).to be_valid
  end

  it "コメントは300文字まで" do
    expect(build(:talk_vote, comment: "あ" * 300)).to be_valid
    expect(build(:talk_vote, comment: "あ" * 301)).to be_invalid
  end

  it "同じLTへの重複はDBでも弾く" do
    talk = create(:talk, event: event)
    create(:talk_vote, user: user, talk: talk)

    duplicate = build(:talk_vote, user: user, talk: talk)

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
