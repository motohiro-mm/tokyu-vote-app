# イベント配下にネストされたコントローラの共通処理。
module EventScoped
  extend ActiveSupport::Concern

  included do
    skip_before_action :require_login
    before_action :set_event
    before_action :require_current_event
    before_action :require_login
    before_action :check_event_status
  end

  private

  def set_event
    @event = Event.find_by!(slug: params[:event_slug])
  end

  def require_current_event
    return if @event == Event.current

    raise ActiveRecord::RecordNotFound unless request.get? || request.head?

    redirect_to request.fullpath.sub(%r{\A/events/}, "/archives/")
  end

  # 準備中と集計中は中身を見せず、状態を説明する画面で止める
  def check_event_status
    case @event.status
    when "preparing" then render "shared/preparing", status: :forbidden
    when "counting" then render "shared/counting", status: :forbidden
    end
  end

  def require_open_event
    return if @event.open?

    redirect_to event_path(@event.slug), alert: "現在は受け付けていません。"
  end
end
