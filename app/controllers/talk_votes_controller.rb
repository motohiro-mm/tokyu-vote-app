class TalkVotesController < ApplicationController
  include EventScoped

  before_action :require_open_event, only: :create

  def create
    talk = @event.talks.votable.find(talk_vote_params[:talk_id])
    talk_vote = current_user.talk_votes.build(talk: talk, comment: talk_vote_params[:comment])

    # 同じユーザーの投票を直列化する。ロックのあとで残票と重複を読み直してから保存する。
    # count < 3 だけだと、別の LT への同時 POST が 3 票を超えられる。
    current_user.with_lock do
      talk_vote.save!
    end

    redirect_to event_talk_votes_completions_path(@event)
  rescue ActiveRecord::RecordInvalid
    redirect_to_talk_with_alert(talk, talk_vote)
  rescue ActiveRecord::RecordNotUnique
    # バリデーションを抜けたあとにユニークインデックスへ当たったときは 500 にしない
    talk_vote.errors.add(:base, :already_voted)
    redirect_to_talk_with_alert(talk, talk_vote)
  end

  def completions
    @category = Category.find_by_name!(:talk)
    @remaining_votes = TalkVote.remaining_for(current_user, @event)
  end

  private

  def talk_vote_params
    params.expect(talk_vote: [ :talk_id, :comment ])
  end

  def redirect_to_talk_with_alert(talk, talk_vote)
    redirect_to event_talk_path(@event, talk), alert: talk_vote.errors.full_messages.to_sentence
  end
end
