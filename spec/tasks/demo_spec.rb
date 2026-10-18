require "rails_helper"
require "rake"

RSpec.describe "demo:results" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  def run_task
    %w[db:seed demo:setup demo:results].each { |name| Rake::Task[name].reenable }
    Rake::Task["demo:results"].invoke
  end

  let(:event) { Event.find_by!(title: "デモイベント") }
  let(:food) { Category.find_by!(category_name: :food) }
  let(:drink) { Category.find_by!(category_name: :drink) }

  it "結果を公開済みのイベントを、投票済みの候補付きで作る" do
    expect { run_task }.to output(/できました: デモイベント/).to_stdout

    expect(event).to be_closed
    expect(event.entries.where(category: food).count).to eq 5
    expect(event.entries.where(category: drink).count).to eq 4
    expect(event.talks.votable.count).to eq 4
    expect(event.talks.where(status: :canceled).count).to eq 1
    expect(Vote.in_category(event, food).count).to be > 0
    expect(TalkVote.in_event(event).count).to be > 0
  end

  it "単品王と合算王で顔ぶれが変わり、同票の並びも見られる" do
    expect { run_task }.to output.to_stdout

    single = Vote.ranking_by_entry(event, food)
    expect(single.first(2).map(&:rank)).to eq [ 1, 1 ]
    expect(single.first(2).map(&:title)).to contain_exactly("唐揚げ", "肉じゃが")

    combined = Vote.ranking_by_user(event, food)
    expect(combined.first.name).to eq "さんかしゃ1"
    expect(combined.map(&:rank)).to eq [ 1, 2, 3, 3 ]

    talks = TalkVote.ranking(event)
    expect(talks.map(&:rank)).to eq [ 1, 1, 3, 3 ]
  end

  it "コメントは投票者を伏せたまま結果画面に出る" do
    expect { run_task }.to output.to_stdout

    result = CategoryResult.new(event, food)
    karaage = result.targets.find { |target| target.title == "唐揚げ" }
    expect(karaage.comments).to include("衣がザクザクで最高でした")
    expect(result.targets.map(&:title)).not_to include("当日欠席になった話")
  end

  it "検証環境のラベルが無い production では実行できない" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

    expect { run_task }.to raise_error(SystemExit).and output(/APP_ENV_LABEL=staging/).to_stderr
    expect(Event.where(title: "デモイベント")).not_to exist
  end

  it "検証環境（APP_ENV_LABEL=staging）では production でも実行できる" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("APP_ENV_LABEL").and_return("staging")
    allow(ENV).to receive(:[]).with("APP_HOST").and_return("vote-staging.example.com")

    expect { run_task }.to output(%r{https://vote-staging.example.com/events/}).to_stdout
    expect(event).to be_closed
  end

  it "2 回実行しても候補と票が増えない" do
    expect { run_task }.to output.to_stdout

    counts = -> { [ Entry.count, Talk.count, Vote.count, TalkVote.count ] }
    before_second_run = counts.call

    expect { run_task }.to output.to_stdout
    expect(counts.call).to eq before_second_run
  end
end
