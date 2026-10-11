# LT候補の CSV 一括登録。フォームはイベントの管理画面に置き、結果はそこへ戻して知らせる。
class Admin::TalkImportsController < Admin::BaseController
  # LT の一覧は数 KB で収まる。ファイル全体をメモリに読むため、桁違いに大きいものは読む前に止める
  CSV_MAX_SIZE = 1.megabyte

  before_action :set_event

  def create
    file = params[:file]
    # 画面のフォームからは必ずファイルが来るが、文字列が送られると .read で 500 になるため、ここで弾く
    unless file.respond_to?(:read) && file.respond_to?(:size)
      return redirect_to admin_event_path(@event), alert: "CSV ファイルを選んでください。"
    end
    if file.size > CSV_MAX_SIZE
      return redirect_to admin_event_path(@event), alert: "CSV ファイルが大きすぎます（#{CSV_MAX_SIZE / 1.megabyte}MB まで）。"
    end

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
