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
      redirect_to admin_event_path(@event), notice: "#{Event.model_name.human}を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    load_show
  end

  def update
    if status_change?
      change_status
    else
      update_edition
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def talks
    @event.talks.order(:id)
  end

  def rankings
    Category.order(:id).flat_map { |category| CategoryResult.new(@event, category).rankings }
  end

  def event_params
    params.expect(event: [ :title, :held_on, :slug ])
  end

  def status_param
    params.expect(event: [ :status ])
  end

  # ステータス変更のフォームだけが status を送る。開催情報の更新では必須にしない
  def status_change?
    params[:event].respond_to?(:key?) && params[:event].key?(:status)
  end

  def change_status
    if @event.update(status_param)
      redirect_to admin_event_path(@event), notice: "#{Event.human_attribute_name(:status)}を変更しました。"
    else
      load_show
      render :show, status: :unprocessable_entity
    end
  end

  def update_edition
    @event.assign_attributes(event_params)
    if @event.save(context: :edition)
      redirect_to admin_event_path(@event), notice: "#{Event.model_name.human}を更新しました。"
    else
      load_show
      render :show, status: :unprocessable_entity
    end
  end

  def load_show
    @talks = talks
    @rankings = rankings if @event.counting_started?
  end
end
