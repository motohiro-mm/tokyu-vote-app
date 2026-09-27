class TalkVote < ApplicationRecord
  include Votable

  belongs_to :talk

  delegate :event, to: :talk

  scope :in_event, ->(event) { joins(:talk).where(talks: { event_id: event }) }
  scope :cast_by, ->(user, event) { in_event(event).where(user_id: user) }

  def self.remaining_for(user, event)
    MAX_VOTES_PER_CATEGORY - cast_by(user, event).count
  end

  # LT王。登壇者は複数回登壇しないため単品王のみ
  def self.ranking(event)
    counts = in_event(event).group(:talk_id).count

    ranked(Talk.where(id: counts.keys).map { |talk|
      { id: talk.id, name: talk.user_name, title: talk.title, vote_count: counts.fetch(talk.id) }
    })
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
