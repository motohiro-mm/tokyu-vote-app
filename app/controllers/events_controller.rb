class EventsController < ApplicationController
  include EventScoped

  def show
    @categories = Category.order(:id)
  end

  def unknown_path
    raise ActiveRecord::RecordNotFound
  end

  private

  def set_event
    @event = Event.find_by!(slug: request.path_parameters[:slug] || request.path_parameters[:event_slug])
  end
end
