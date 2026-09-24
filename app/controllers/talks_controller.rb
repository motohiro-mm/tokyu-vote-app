class TalksController < ApplicationController
  include EventScoped

  before_action :set_category

  def index
    @talks = @event.talks.votable.order(:id)
    @voted_talks = TalkVote.cast_by(current_user, @event).includes(:talk).map(&:talk)
    @voted_talk_ids = @voted_talks.map(&:id)
    @remaining_votes = TalkVote.remaining_for(current_user, @event)
  end

  def show
    @talk = @event.talks.votable.find(params[:id])
    @talk_vote = TalkVote.new(talk: @talk)
    @voted = current_user.talk_votes.exists?(talk: @talk)
    @remaining_votes = TalkVote.remaining_for(current_user, @event)
  end

  private

  def set_category
    @category = Category.find_by_name!(:talk)
  end
end
