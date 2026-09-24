class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title, null: false
      # 0:preparing 1:open 2:counting 3:closed
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
