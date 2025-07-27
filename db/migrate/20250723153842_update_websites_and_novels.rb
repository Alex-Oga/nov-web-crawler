class UpdateWebsitesAndNovels < ActiveRecord::Migration[8.0]
  def change
    rename_column :websites, :novel_amount, :novels
    add_column :novels, :name, :string
  end
end