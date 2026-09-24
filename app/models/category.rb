# 画面上の部門（飯王・酒王・LT王）のマスタ。
# 投票対象の実体は部門によって違い、LT王だけ entries ではなく talks を使う。
class Category < ApplicationRecord
  enum :category_name, { food: "food", drink: "drink", lt: "lt" }, validate: true

  has_many :entries, dependent: :restrict_with_error

  validates :category_name, presence: true, uniqueness: true

  # 未知の部門名を渡されたときに nil を返して NoMethodError にせず、
  # 存在しない部門として扱えるようホワイトリストで引く
  def self.find_by_name!(name)
    raise ActiveRecord::RecordNotFound unless category_names.key?(name.to_s)

    find_by!(category_name: name)
  end

  def votable_model
    lt? ? Talk : Entry
  end
end
