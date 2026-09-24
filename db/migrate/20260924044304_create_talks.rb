class CreateTalks < ActiveRecord::Migration[8.1]
  def change
    create_table :talks do |t|
      t.references :event, null: false, foreign_key: true
      # 登壇者は投票アプリにログインしないため、users を参照せず名前を文字列で持つ
      t.string :user_name, null: false
      t.string :title, null: false
      # 0:scheduled 1:canceled
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :talks, [ :event_id, :status ]
  end
end
