class TalkVote < ApplicationRecord
  include Votable

  belongs_to :talk

  delegate :event, to: :talk

  scope :cast_by, ->(user, event) {
    joins(:talk).where(user_id: user, talks: { event_id: event })
  }

  def self.remaining_for(user, event)
    MAX_VOTES_PER_CATEGORY - cast_by(user, event).count
  end

  private

  def vote_target
    talk
  end

  def votes_in_same_category
    TalkVote.cast_by(user_id, talk.event_id)
  end

  def votes_for_same_target
    TalkVote.where(user_id: user_id, talk_id: talk_id)
  end
end
