class AddSlideUrlToTalks < ActiveRecord::Migration[8.1]
  def change
    add_column :talks, :slide_url, :string
  end
end
