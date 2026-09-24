require "rails_helper"

RSpec.describe "LT王への投票", type: :request do
  let(:event) { create(:event, status: :open) }
  let(:user) { create(:user) }

  def cast(talk, comment: "よかった")
    post event_talk_votes_path(event), params: { talk_vote: { talk_id: talk.id, comment: comment } }
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

  it "締切後は投票できない" do
    talk = create(:talk, event: event)
    event.counting!

    expect { cast(talk) }.not_to change(TalkVote, :count)
  end
end
