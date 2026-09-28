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
    @rankings = rankings if @event.counting_started?
  end

  def update
    if @event.update(status_param)
      redirect_to admin_event_path(@event), notice: "ステータスを変更しました。"
    else
      @rankings = rankings if @event.counting_started?
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def rankings
    Category.order(:id).flat_map { |category| CategoryResult.new(@event, category).rankings }
  end

  def event_params
    params.expect(event: [ :title ])
  end

  def status_param
    params.expect(event: [ :status ])
  end
end
