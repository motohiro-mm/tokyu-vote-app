class EventsController < ApplicationController
  include EventScoped

  def show
    @categories = Category.order(:id)
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end
end
