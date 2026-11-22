# 結果一覧と投票対象ごとの結果で、公開前に見せない判定を揃える。EventScoped の後に include する
module ResultsPublished
  extend ActiveSupport::Concern

  included do
    before_action :require_results_published
  end

  private

  def require_results_published
    return if @event.results_published?

    redirect_to event_path(@event.slug), alert: "結果はまだ公開されていません。"
  end
end
