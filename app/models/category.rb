# 画面上の部門（飯王・酒王・LT王）のマスタ。
# 投票対象のモデルは部門によって違い、LT王だけ entries ではなく talks を使う。
class Category < ApplicationRecord
  enum :category_name, { food: "food", drink: "drink", talk: "talk" }, validate: true

  has_many :entries, dependent: :restrict_with_error

  validates :category_name, presence: true, uniqueness: true

  # LT王の候補は管理者が talks に登録するため、参加者が登録できる部門から外す
  scope :for_entries, -> { where.not(category_name: :talk) }

  # 未知の部門名を渡されたときに nil を返して NoMethodError にせず、
  # 存在しない部門として扱えるようホワイトリストで引く。
  # for_entries などのスコープ越しに呼べば、範囲外の部門も同じく 404 になる
  def self.find_by_name!(name)
    raise ActiveRecord::RecordNotFound unless category_names.key?(name.to_s)

    find_by!(category_name: name)
  end

  def label
    I18n.t("enums.category.category_name.#{category_name}")
  end

  def description
    I18n.t("categories.descriptions.#{category_name}")
  end
end
