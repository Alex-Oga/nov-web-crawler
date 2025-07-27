class AddNameToNovelsAndRenameNovelAmount < ActiveRecord::Migration[8.0]
  def change
    # Add name to novels
    add_column :novels, :name, :string
    
    # Rename novel_amount to novels in websites
    rename_column :websites, :novel_amount, :novels
  end
end
