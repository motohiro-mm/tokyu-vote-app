class HomeController < ApplicationController
  def index
    events = Event.where.not(status: :finished).order(created_at: :desc, id: :desc)
    @event = events.where(status: %i[open counting]).first || events.first
    return render :index if @event&.slug.blank?

    redirect_to event_path(@event.slug)
  end
end
