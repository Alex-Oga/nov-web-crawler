class AddImageUrlAndDescriptionToNovels < ActiveRecord::Migration[8.0]
  def change
    add_column :novels, :image_url, :string
    add_column :novels, :description, :text
    add_index :novels, :image_url
  end
end