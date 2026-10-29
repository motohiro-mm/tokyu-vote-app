class Event < ApplicationRecord
  # 回次の公開キー。例: "17" や "tokyu-17"。英数字とハイフン以外は URL にしない
  SLUG_FORMAT = /\A[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*\z/

  # finished は結果公開を終えて役目を終えた状態。トップページで次のイベントが作られるまで
  # 前回の結果を出し続けないために、closed とは別に持つ
  enum :status, { preparing: 0, open: 1, counting: 2, closed: 3, finished: 4 }, validate: true

  # 一般向けに出す候補。終了した回は含めない
  scope :not_finished, -> { where.not(status: :finished) }

  def self.current
    not_finished.order(created_at: :desc).first
  end

  has_many :entries, dependent: :destroy
  has_many :talks, dependent: :destroy

  before_validation :normalize_slug

  validates :title, presence: true
  # DB では既存行のために null を許す。新規作成と管理画面の開催情報の更新では必須。
  # ステータス変更は :update のままなので、未設定の既存行でも止めない
  validates :held_on, presence: true, on: %i[create edition]
  validates :slug, presence: true, on: %i[create edition]
  validates :slug, uniqueness: { allow_nil: true }, format: { with: SLUG_FORMAT, allow_nil: true }

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

  # 終了しても結果そのものは残す
  def results_published?
    closed? || finished?
  end

  private

  def normalize_slug
    self.slug = slug.strip.presence if slug.is_a?(String)
  end
end
