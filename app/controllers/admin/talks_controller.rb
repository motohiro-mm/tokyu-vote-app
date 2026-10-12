class Admin::TalksController < Admin::BaseController
  before_action :set_event
  before_action :set_talk, only: [ :edit, :update ]
  before_action :require_accepting_talks, only: [ :new, :create ]

  def new
    @talk = @event.talks.build
  end

  def create
    @talk = @event.talks.build(talk_params)

    if @talk.save
      redirect_to admin_event_path(@event), notice: "LTを登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @talk.update(talk_params)
      redirect_to admin_event_path(@event), notice: "LTを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_talk
    @talk = @event.talks.find(params[:id])
  end

  def require_accepting_talks
    return if @event.accepting_talks?

    redirect_to admin_event_path(@event), alert: "LTの登録は#{Event.status_label(:preparing)}・#{Event.status_label(:open)}のあいだだけできます。"
  end

  def talk_params
    params.expect(talk: [ :user_name, :title, :status ])
  end
end
