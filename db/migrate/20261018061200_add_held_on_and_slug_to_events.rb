class AddHeldOnAndSlugToEvents < ActiveRecord::Migration[8.1]
  def change
    # 既存のイベントは開催日もスラッグも未設定のまま残す。
    # NOT NULL にすると、すでに行がある環境で移行が失敗する。
    add_column :events, :held_on, :date
    add_column :events, :slug, :string
    add_index :events, :slug, unique: true
  end
end
