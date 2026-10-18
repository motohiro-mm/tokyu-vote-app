require "rails_helper"

RSpec.describe "リクエストログのパラメータフィルタ" do
  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  it "誰が何に投票したかが分かる値をログに残さない" do
    filtered = filter.filter(
      "vote" => { "entry_id" => "3", "comment" => "うまい" },
      "talk_vote" => { "talk_id" => "7", "comment" => "よかった" }
    )

    expect(filtered["vote"]).to eq("entry_id" => "[FILTERED]", "comment" => "[FILTERED]")
    expect(filtered["talk_vote"]).to eq("talk_id" => "[FILTERED]", "comment" => "[FILTERED]")
  end

  it "エントリーの題名や説明は残す" do
    filtered = filter.filter("entry" => { "title" => "唐揚げ", "description" => "揚げたて" })

    expect(filtered["entry"]).to eq("title" => "唐揚げ", "description" => "揚げたて")
  end
end
