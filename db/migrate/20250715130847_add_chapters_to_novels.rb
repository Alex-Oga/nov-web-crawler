class AddChaptersToNovels < ActiveRecord::Migration[8.0]
  def change
    add_column :novels, :chapters, :integer
  end
end
