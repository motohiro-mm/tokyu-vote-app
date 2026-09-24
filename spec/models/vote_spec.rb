require "rails_helper"

RSpec.describe Vote do
  let(:event) { create(:event, status: :open) }
  let(:category) { create(:category, category_name: :food) }
  let(:user) { create(:user) }

  def entry_in(target_category = category)
    create(:entry, event: event, category: target_category)
  end

  it "同じエントリーには2票目を投じられない" do
    entry = entry_in
    create(:vote, user: user, entry: entry)

    vote = build(:vote, user: user, entry: entry)

    expect(vote).to be_invalid
    expect(vote.errors[:base]).to include("同じエントリーには投票できません")
  end

  it "同じ部門には3票までしか投じられない" do
    3.times { create(:vote, user: user, entry: entry_in) }

    vote = build(:vote, user: user, entry: entry_in)

    expect(vote).to be_invalid
    expect(vote.errors[:base]).to include("1つの部門に投票できるのは3票までです")
  end

  it "票数は部門ごとに数える" do
    3.times { create(:vote, user: user, entry: entry_in) }
    drink = create(:category, category_name: :drink)

    expect(build(:vote, user: user, entry: entry_in(drink))).to be_valid
  end

  it "票数はイベントごとに数える" do
    3.times { create(:vote, user: user, entry: entry_in) }
    other_event_entry = create(:entry, event: create(:event), category: category)

    expect(build(:vote, user: user, entry: other_event_entry)).to be_valid
  end

  it "別のユーザーの票は自分の票数に数えない" do
    3.times { create(:vote, user: create(:user), entry: entry_in) }

    expect(build(:vote, user: user, entry: entry_in)).to be_valid
  end

  it "コメントは300文字まで" do
    expect(build(:vote, comment: "あ" * 300)).to be_valid
    expect(build(:vote, comment: "あ" * 301)).to be_invalid
  end

  it "同じエントリーへの重複はDBでも弾く" do
    entry = entry_in
    create(:vote, user: user, entry: entry)

    duplicate = build(:vote, user: user, entry: entry)

    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
