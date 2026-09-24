class User < ApplicationRecord
  has_many :entries, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :talk_votes, dependent: :destroy

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :name, presence: true
end
