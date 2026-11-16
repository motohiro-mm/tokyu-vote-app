require "rails_helper"

RSpec.describe "LT王への投票", type: :request do
  let(:event) { create(:event, status: :open) }
  let(:user) { create(:user) }

  def cast(talk, comment: "よかった")
    post event_talk_votes_path(event.slug), params: { talk_vote: { talk_id: talk.id, comment: comment } }
  end

  before { sign_in(user) }

  it "投票できる" do
    talk = create(:talk, event: event)

    expect { cast(talk) }.to change(TalkVote, :count).by(1)
  end

  it "同じLTには2回投票できない" do
    talk = create(:talk, event: event)
    cast(talk)

    expect { cast(talk) }.not_to change(TalkVote, :count)
    expect(flash[:alert]).to include("同じLTには投票できません")
  end

  it "4票目は投票できない" do
    3.times { cast(create(:talk, event: event)) }

    expect { cast(create(:talk, event: event)) }.not_to change(TalkVote, :count)
  end

  it "キャンセルされたLTには投票できない" do
    talk = create(:talk, event: event, status: :canceled)

    expect { cast(talk) }.not_to change(TalkVote, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "別のイベントのLTには投票できない" do
    talk = create(:talk, event: create(:event, status: :open))

    expect { cast(talk) }.not_to change(TalkVote, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "締切後は投票できない" do
    talk = create(:talk, event: event)
    event.counting!

    expect { cast(talk) }.not_to change(TalkVote, :count)
  end

  it "ユニーク制約に当たっても500にせず同じLTへの案内を返す" do
    talk = create(:talk, event: event)
    cast(talk)
    allow_any_instance_of(TalkVote).to receive(:valid?).and_return(true)

    expect { cast(talk) }.not_to change(TalkVote, :count)
    expect(response).to have_http_status(:redirect)
    expect(flash[:alert]).to include("同じLTには投票できません")
  end

  # トランザクションで包むとスレッドが同じ接続を使い、同時実行にならない
  describe "同時に届いた投票" do
    self.use_transactional_tests = false
    uses_transaction "2スレッドが別々のLTに投票しても3票を超えない"
    uses_transaction "同じLTへの同時投票は500にならない"

    after do
      Vote.delete_all
      TalkVote.delete_all
      Entry.delete_all
      Talk.delete_all
      User.delete_all
      Event.delete_all
      Category.delete_all
    end

    it "2スレッドが別々のLTに投票しても3票を超えない" do
      2.times { cast(create(:talk, event: event)) }
      targets = Array.new(2) { create(:talk, event: event) }

      payloads = targets.map do |talk|
        [ event_talk_votes_path(event.slug), { talk_vote: { talk_id: talk.id, comment: "同時" } } ]
      end

      sessions = post_concurrently(payloads)

      expect(TalkVote.cast_by(user, event).count).to eq(3)
      expect(TalkVote.where(user: user, talk_id: targets.map(&:id)).count).to eq(1)
      expect(sessions.map(&:response)).to all(be_redirect)
    end

    it "同じLTへの同時投票は500にならない" do
      talk = create(:talk, event: event)

      sessions = post_concurrently([
        [ event_talk_votes_path(event.slug), { talk_vote: { talk_id: talk.id, comment: "同時1" } } ],
        [ event_talk_votes_path(event.slug), { talk_vote: { talk_id: talk.id, comment: "同時2" } } ]
      ])

      expect(TalkVote.where(user: user, talk: talk).count).to eq(1)
      expect(sessions.map(&:response)).to all(be_redirect)
      expect(sessions.filter_map { |session| session.flash[:alert] }.join).to include("同じLTには投票できません")
    end
  end

  describe "取り消し" do
    let(:talk) { create(:talk, event: event) }

    it "取り消すとコメントごと票が消え、残票が戻る" do
      cast(talk, comment: "取り消すコメント")
      talk_vote = TalkVote.last

      expect { delete event_talk_vote_path(event.slug, talk_vote) }.to change(TalkVote, :count).by(-1)
      expect(TalkVote.where(comment: "取り消すコメント")).not_to exist
      expect(TalkVote.remaining_for(user, event)).to eq 3
      expect(response).to redirect_to event_talk_path(event.slug, talk)
      expect(flash[:notice]).to eq "投票を取り消しました。"
    end

    it "取り消したあと別のLTへ入れ直せる" do
      3.times { cast(create(:talk, event: event)) }
      delete event_talk_vote_path(event.slug, TalkVote.last)

      expect { cast(talk) }.to change(TalkVote, :count).by(1)
    end

    it "他人の票は取り消せない" do
      other_vote = create(:talk_vote, talk: talk)

      expect { delete event_talk_vote_path(event.slug, other_vote) }.not_to change(TalkVote, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "別のイベントの票は、そのイベントの URL からは取り消せない" do
      other_event = create(:event, status: :finished)
      talk_vote = create(:talk_vote, user: user, talk: create(:talk, event: other_event))

      expect { delete event_talk_vote_path(event.slug, talk_vote) }.not_to change(TalkVote, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "締切後は取り消せない" do
      cast(talk)
      event.counting!

      expect { delete event_talk_vote_path(event.slug, TalkVote.last) }.not_to change(TalkVote, :count)
    end

    it "投票済みのLT画面に取り消しボタンを出す" do
      create(:category, category_name: :talk)
      cast(talk)
      get event_talk_path(event.slug, talk)

      action = event_talk_vote_path(event.slug, TalkVote.last)
      expect(response.parsed_body.at_css("form[action='#{action}'] button").text).to eq "投票を取り消す"
    end
  end
end
