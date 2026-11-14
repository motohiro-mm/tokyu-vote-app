require "rails_helper"

RSpec.describe "投票", type: :request do
  let(:event) { create(:event, status: :open) }
  let(:food) { create(:category, category_name: :food) }
  let(:drink) { create(:category, category_name: :drink) }
  let(:user) { create(:user) }

  def cast(entry, comment: "おいしい")
    post event_votes_path(event.slug), params: { vote: { entry_id: entry.id, comment: comment } }
  end

  before { sign_in(user) }

  it "投票できる" do
    entry = create(:entry, event: event, category: food)

    expect { cast(entry) }.to change(Vote, :count).by(1)
  end

  it "自分のエントリーには投票できない" do
    entry = create(:entry, event: event, category: food, user: user)

    expect { cast(entry) }.not_to change(Vote, :count)
    expect(flash[:alert]).to include("自分のエントリーには投票できません")
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

  it "別のイベントのエントリーには投票できない" do
    entry = create(:entry, event: create(:event, status: :open), category: food)

    expect { cast(entry) }.not_to change(Vote, :count)
    expect(response).to have_http_status(:not_found)
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

  it "ユニーク制約に当たっても500にせず同じエントリーへの案内を返す" do
    entry = create(:entry, event: event, category: food)
    cast(entry)
    allow_any_instance_of(Vote).to receive(:valid?).and_return(true)

    expect { cast(entry) }.not_to change(Vote, :count)
    expect(response).to have_http_status(:redirect)
    expect(flash[:alert]).to include("同じエントリーには投票できません")
  end

  # トランザクションで包むとスレッドが同じ接続を使い、同時実行にならない
  describe "同時に届いた投票" do
    self.use_transactional_tests = false
    uses_transaction "2スレッドが別々の対象に投票しても3票を超えない"
    uses_transaction "同じ対象への同時投票は500にならない"

    after do
      Vote.delete_all
      TalkVote.delete_all
      Entry.delete_all
      Talk.delete_all
      User.delete_all
      Event.delete_all
      Category.delete_all
    end

    it "2スレッドが別々の対象に投票しても3票を超えない" do
      2.times { cast(create(:entry, event: event, category: food)) }
      targets = Array.new(2) { create(:entry, event: event, category: food) }
      payloads = targets.map do |entry|
        [ event_votes_path(event.slug), { vote: { entry_id: entry.id, comment: "同時" } } ]
      end

      sessions = post_concurrently(payloads)

      expect(Vote.cast_by(user, event, food).count).to eq(3)
      expect(Vote.where(user: user, entry_id: targets.map(&:id)).count).to eq(1)
      expect(sessions.map(&:response)).to all(be_redirect)
    end

    it "同じ対象への同時投票は500にならない" do
      entry = create(:entry, event: event, category: food)

      sessions = post_concurrently([
        [ event_votes_path(event.slug), { vote: { entry_id: entry.id, comment: "同時1" } } ],
        [ event_votes_path(event.slug), { vote: { entry_id: entry.id, comment: "同時2" } } ]
      ])

      expect(Vote.where(user: user, entry: entry).count).to eq(1)
      expect(sessions.map(&:response)).to all(be_redirect)
      expect(sessions.filter_map { |session| session.flash[:alert] }.join).to include("同じエントリーには投票できません")
    end
  end

  describe "取り消し" do
    let(:entry) { create(:entry, event: event, category: food) }

    it "取り消すとコメントごと票が消え、残票が戻る" do
      cast(entry, comment: "取り消すコメント")
      vote = Vote.last

      expect { delete event_vote_path(event.slug, vote) }.to change(Vote, :count).by(-1)
      expect(Vote.where(comment: "取り消すコメント")).not_to exist
      expect(Vote.remaining_for(user, event, food)).to eq 3
      expect(response).to redirect_to event_entry_path(event.slug, entry, category: "food")
      expect(flash[:notice]).to eq "投票を取り消しました。"
    end

    it "取り消したあと別のエントリーへ入れ直せる" do
      3.times { cast(create(:entry, event: event, category: food)) }
      delete event_vote_path(event.slug, Vote.last)

      expect { cast(entry) }.to change(Vote, :count).by(1)
    end

    it "他人の票は取り消せない" do
      other_vote = create(:vote, entry: entry)

      expect { delete event_vote_path(event.slug, other_vote) }.not_to change(Vote, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "別のイベントの票は、そのイベントの URL からは取り消せない" do
      other_event = create(:event, status: :finished)
      vote = create(:vote, user: user, entry: create(:entry, event: other_event, category: food))

      expect { delete event_vote_path(event.slug, vote) }.not_to change(Vote, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "締切後は取り消せない" do
      cast(entry)
      event.counting!

      expect { delete event_vote_path(event.slug, Vote.last) }.not_to change(Vote, :count)
    end

    it "投票済みのエントリー画面に取り消しボタンを出す" do
      cast(entry)
      get event_entry_path(event.slug, entry, category: "food")

      form = response.parsed_body.at_css("form[action='#{event_vote_path(event.slug, Vote.last)}']")
      expect(form.text).to include("投票を取り消す")
    end
  end
end
