class ResultsController < ApplicationController
  include EventScoped

  before_action :require_closed_event

  def index
    @category = Category.find_by_name!(params[:category])
    @result = CategoryResult.new(@event, @category)
  end

  private

  def require_closed_event
    return if @event.closed?

    redirect_to event_path(@event), alert: "結果はまだ公開されていません。"
  end
end
