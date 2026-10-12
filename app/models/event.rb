class Event < ApplicationRecord
  enum :status, { preparing: 0, open: 1, counting: 2, closed: 3 }, validate: true

  has_many :entries, dependent: :destroy
  has_many :talks, dependent: :destroy

  validates :title, presence: true

  def self.status_label(status)
    I18n.t("enums.event.status.#{status}")
  end

  def status_label
    self.class.status_label(status)
  end

  # 集計に入ってから候補が増えると票の扱いが決まらないため、LT の登録は受付中まで
  def accepting_talks?
    preparing? || open?
  end

  def counting_started?
    counting? || closed?
  end
end
