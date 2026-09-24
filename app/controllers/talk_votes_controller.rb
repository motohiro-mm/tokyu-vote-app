class TalkVotesController < ApplicationController
  include EventScoped

  before_action :require_open_event, only: :create

  def create
    talk = @event.talks.votable.find(talk_vote_params[:talk_id])
    talk_vote = current_user.talk_votes.build(talk: talk, comment: talk_vote_params[:comment])

    if talk_vote.save
      redirect_to event_talk_votes_completions_path(@event)
    else
      redirect_to event_talk_path(@event, talk), alert: talk_vote.errors.full_messages.to_sentence
    end
  end

  def completions
    @remaining_votes = TalkVote.remaining_for(current_user, @event)
  end

  private

  def talk_vote_params
    params.expect(talk_vote: [ :talk_id, :comment ])
  end
end
