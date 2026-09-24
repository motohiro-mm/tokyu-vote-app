class EntriesController < ApplicationController
  include EventScoped

  before_action :set_category, except: :categories
  before_action :require_open_event, only: [ :new, :create ]

  def categories
    @categories = Category.for_entries.order(:id)
  end

  def index
    @entries = @event.entries.where(category: @category).includes(:user).with_attached_image.order(:id)
    @voted_entries = Vote.cast_by(current_user, @event, @category).includes(entry: :user).map(&:entry)
    @voted_entry_ids = @voted_entries.map(&:id)
    @remaining_votes = Vote.remaining_for(current_user, @event, @category)
  end

  def show
    @entry = @event.entries.where(category: @category).find(params[:id])
    @vote = Vote.new(entry: @entry)
    @voted = current_user.votes.exists?(entry: @entry)
    @remaining_votes = Vote.remaining_for(current_user, @event, @category)
  end

  def new
    @entry = @event.entries.build(category: @category)
    @my_entries = my_entries
  end

  def create
    @entry = @event.entries.build(entry_params.merge(category: @category, user: current_user))

    if @entry.save
      redirect_to event_entries_completions_path(@event, category: @category.category_name)
    else
      @my_entries = my_entries
      render :new, status: :unprocessable_entity
    end
  end

  def completions; end

  private

  def my_entries
    @event.entries.where(category: @category, user: current_user).order(:id)
  end

  # LT候補は talks が持つため、ここで受け付けるのは飯王・酒王だけ。
  # 未知の部門名も LT王もそのまま 404 にする
  def set_category
    @category = Category.for_entries.find_by_name!(params[:category])
  end

  def entry_params
    params.expect(entry: [ :title, :description, :image ])
  end
end
