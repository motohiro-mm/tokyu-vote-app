# イベント配下にネストされたコントローラの共通処理。
module EventScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_event
    before_action :check_event_status
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  # 準備中と集計中は中身を見せず、状態を説明する画面で止める
  def check_event_status
    case @event.status
    when "preparing" then render "shared/preparing", status: :forbidden
    when "counting" then render "shared/counting", status: :forbidden
    end
  end

  # エントリーと投票を受け付けるのは公開中だけ
  def require_open_event
    return if @event.open?

    redirect_to event_path(@event), alert: "現在は受け付けていません。"
  end
end
