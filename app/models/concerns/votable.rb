# 飯王・酒王への投票（Vote）と LT王への投票（TalkVote）で共通する投票ルール。
# 投票対象のテーブルが分かれているため、対象の引き方だけを各モデルに任せる。
module Votable
  extend ActiveSupport::Concern

  # 1ユーザーが1イベント × 1部門に投じられる票数の上限
  MAX_VOTES_PER_CATEGORY = 3

  TOP_RANKS = 3

  RankingRow = Data.define(:rank, :name, :title, :vote_count)

  included do
    belongs_to :user

    validates :comment, length: { maximum: 300 }
    validate :vote_limit_not_exceeded, on: :create
    validate :not_voted_for_same_target, on: :create
  end

  class_methods do
    private

    # 同票は同じ順位にし、次の順位はその分だけ飛ばす（1位が2件なら次は3位）。
    # 3位が同票で並んだときは4件以上になっても全件載せる
    def ranked(sources)
      rank = 0
      previous_count = nil

      # 同票の並び順が実行のたびに変わらないよう、得票数の次は id で並べる
      sources.sort_by { |source| [ -source[:vote_count], source[:id] ] }
             .each_with_index
             .filter_map do |source, index|
        rank = index + 1 unless source[:vote_count] == previous_count
        previous_count = source[:vote_count]
        next if rank > TOP_RANKS

        RankingRow.new(rank: rank, name: source[:name], title: source[:title], vote_count: source[:vote_count])
      end
    end
  end

  private

  # 投票対象。各モデルで定義する
  def vote_target
    raise NotImplementedError
  end

  # 同じユーザーが同じイベント・同じ部門に投じた票。各モデルで定義する
  def votes_in_same_category
    raise NotImplementedError
  end

  # 同じユーザーが同じ対象に投じた票。各モデルで定義する
  def votes_for_same_target
    raise NotImplementedError
  end

  def vote_limit_not_exceeded
    return if user.nil? || vote_target.nil?
    return if votes_in_same_category.count < MAX_VOTES_PER_CATEGORY

    errors.add(:base, :vote_limit_exceeded)
  end

  # ユニークインデックスと同じ条件をモデル側にも置き、保存前に画面へ返せるようにする
  def not_voted_for_same_target
    return if user.nil? || vote_target.nil?

    errors.add(:base, :already_voted) if votes_for_same_target.exists?
  end
end
