class HomeController < ApplicationController
  def index
    current_event = Event.current
    return render :index if current_event.nil?

    redirect_to event_path(current_event)
  end
end
