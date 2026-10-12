class ResultsController < ApplicationController
  include EventScoped

  before_action :require_results_published

  def index
    @category = Category.find_by_name!(params[:category])
    @result = CategoryResult.new(@event, @category)
  end

  private

  def require_results_published
    return if @event.results_published?

    redirect_to event_path(@event), alert: "結果はまだ公開されていません。"
  end
end
