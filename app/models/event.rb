class Event < ApplicationRecord
  # finished は結果公開を終えて役目を終えた状態。トップページで次のイベントが作られるまで
  # 前回の結果を出し続けないために、closed とは別に持つ
  enum :status, { preparing: 0, open: 1, counting: 2, closed: 3, finished: 4 }, validate: true

  # トップページから案内する候補。終了したイベントはリンクを知っている人だけが見られればよい
  scope :not_finished, -> { where.not(status: :finished) }

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
    counting? || results_published?
  end

  # 終了しても結果そのものは消さず、URL を知っていれば見られるようにしておく
  def results_published?
    closed? || finished?
  end
end
