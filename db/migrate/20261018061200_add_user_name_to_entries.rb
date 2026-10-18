class AddUserNameToEntries < ActiveRecord::Migration[8.1]
  def up
    add_column :entries, :user_name, :string

    # これまでの飯王・酒王は登録時点の名前を残していない。空欄にしないため、今の users.name で埋める
    execute <<~SQL.squish
      UPDATE entries
      SET user_name = (SELECT users.name FROM users WHERE users.id = entries.user_id)
    SQL

    change_column_null :entries, :user_name, false
  end

  def down
    remove_column :entries, :user_name
  end
end
