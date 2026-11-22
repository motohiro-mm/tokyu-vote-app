class ResultsController < ApplicationController
  include EventScoped

  before_action :require_results_published
  before_action :set_result

  def index; end

  # 投票画面の詳細は投票のための画面なので、結果からは順位とコメントを添えた別の画面で見せる
  def show
    @target = if @category.talk?
                @event.talks.votable.find(params[:id])
    else
                @event.entries.where(category: @category).includes(:user).with_attached_images.find(params[:id])
    end
  end

  private

  def set_result
    @category = Category.find_by_name!(params[:category])
    @result = CategoryResult.new(@event, @category)
  end

  def require_results_published
    return if @event.results_published?

    redirect_to event_path(@event.slug), alert: "結果はまだ公開されていません。"
  end
end
