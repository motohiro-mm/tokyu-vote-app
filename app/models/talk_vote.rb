# LT王への投票。部門が LT ひとつしかないため、票数の上限はイベント単位で数える。
class TalkVote < ApplicationRecord
  include Votable

  belongs_to :talk

  delegate :event, to: :talk

  private

  def vote_target
    talk
  end

  def votes_in_same_category
    TalkVote.joins(:talk).where(
      user_id: user_id,
      talks: { event_id: talk.event_id }
    )
  end

  def votes_for_same_target
    TalkVote.where(user_id: user_id, talk_id: talk_id)
  end
end
