class FixWebsitesAndNovelsColumns < ActiveRecord::Migration[8.0]
  def change
    # Check if novel_amount exists and novels doesn't, then rename
    if column_exists?(:websites, :novel_amount) && !column_exists?(:websites, :novels)
      rename_column :websites, :novel_amount, :novels
    end
    
    # Add name to novels if it doesn't exist
    unless column_exists?(:novels, :name)
      add_column :novels, :name, :string
    end
  end
end
