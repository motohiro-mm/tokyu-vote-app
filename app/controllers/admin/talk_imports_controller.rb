# LT候補の CSV 一括登録。フォームはイベントの管理画面に置き、結果はそこへ戻して知らせる。
class Admin::TalkImportsController < Admin::BaseController
  before_action :set_event

  def create
    file = params[:file]
    return redirect_to admin_event_path(@event), alert: "CSV ファイルを選んでください。" if file.blank?

    import = TalkCsvImport.new(@event, file.read)

    if import.save
      redirect_to admin_event_path(@event), notice: "#{import.talks.size} 件のLTを登録しました。"
    else
      redirect_to admin_event_path(@event), alert: import.errors.to_sentence
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end
end
