class HomeController < ApplicationController
  def index
    latest_event = Event.order(created_at: :desc).first
    return render :index if latest_event.nil?

    redirect_to event_path(latest_event)
  end
end
