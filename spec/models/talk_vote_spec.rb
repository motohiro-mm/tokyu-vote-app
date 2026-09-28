require "rails_helper"

RSpec.describe TalkVote do
  let(:event) { create(:event, status: :open) }
  let(:user) { create(:user) }

  # 1ユーザーが投じられるのは3票までなので、票数の分だけ投票者を作る
  def vote_for_talk(talk, count)
    count.times { create(:talk_vote, user: create(:user), talk: talk) }
  end

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

  describe ".ranking" do
    it "LT単位の得票数を多い順に返す" do
      talk = create(:talk, event: event, user_name: "登壇者A", title: "Ruby の話")
      vote_for_talk(talk, 2)
      vote_for_talk(create(:talk, event: event), 1)

      rows = described_class.ranking(event)

      expect(rows.map(&:rank)).to eq [ 1, 2 ]
      expect(rows.first).to have_attributes(name: "登壇者A", title: "Ruby の話", vote_count: 2)
    end

    it "他のイベントの票は数えない" do
      vote_for_talk(create(:talk, event: create(:event)), 2)

      expect(described_class.ranking(event)).to be_empty
    end
  end
end
