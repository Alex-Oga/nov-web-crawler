class RemoveRedundantCounters < ActiveRecord::Migration[8.0]
  def change
    remove_column :novels, :chapters, :integer
    remove_column :websites, :novels, :integer
  end
end