class Event < ApplicationRecord
  enum :status, { preparing: 0, open: 1, counting: 2, closed: 3 }, validate: true

  has_many :entries, dependent: :destroy
  has_many :talks, dependent: :destroy

  validates :title, presence: true
end
