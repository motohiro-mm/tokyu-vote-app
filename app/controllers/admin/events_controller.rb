class Admin::EventsController < Admin::BaseController
  before_action :set_event, only: [ :show, :update ]

  def index
    @events = Event.order(created_at: :desc)
  end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)

    if @event.save
      redirect_to admin_event_path(@event), notice: "イベントを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @rankings = rankings
  end

  def update
    if @event.update(status_param)
      redirect_to admin_event_path(@event), notice: "ステータスを変更しました。"
    else
      @rankings = rankings
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  # 管理者は締切前でも結果を確認できる。部門ごとに単品王と合算王を並べる
  def rankings
    entry_rankings = Category.for_entries.order(:id).flat_map do |category|
      [
        [ "#{category.label}（単品王）", Ranking.singles(@event, category) ],
        [ "#{category.label}（合算王）", Ranking.totals(@event, category) ]
      ]
    end

    # LT王は登壇者を users と紐づけていないため合算王を出せない
    entry_rankings << [ "#{Category.find_by_name!(:talk).label}（単品王）", Ranking.talks(@event) ]
  end

  def event_params
    params.expect(event: [ :title ])
  end

  def status_param
    params.expect(event: [ :status ])
  end
end
