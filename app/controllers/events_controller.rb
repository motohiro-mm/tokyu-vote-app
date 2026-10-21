class EventsController < ApplicationController
  include EventScoped

  def show
    @categories = Category.order(:id)
  end

  private

    def set_event
      # クエリの slug や id では切り替えない。パスに載った方だけで決める
      slug = request.path_parameters[:slug]
      @event = slug.present? ? Event.find_by!(slug: slug) : Event.find(params[:id])
    end
end
