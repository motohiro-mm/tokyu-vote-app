# LT王の候補。登壇者は投票アプリにログインしないため users とは紐づけない。
class Talk < ApplicationRecord
  enum :status, { scheduled: 0, canceled: 1 }, validate: true

  belongs_to :event

  has_many :talk_votes, dependent: :destroy

  # 除外する状態ではなく許可する状態を列挙する。
  # 将来「保留」のような状態を足したときに、自動で投票対象から外れるため
  scope :votable, -> { where(status: :scheduled) }

  validates :user_name, presence: true
  validates :title, presence: true
  validate :status_changeable_only_before_voting, if: :status_changed?

  private

  # 票が入った後のキャンセルは票の扱いが決まっていないため、投票開始前しか認めない
  def status_changeable_only_before_voting
    return if new_record?
    return if event&.preparing?

    errors.add(:status, :not_allowed_after_voting_started)
  end
end
