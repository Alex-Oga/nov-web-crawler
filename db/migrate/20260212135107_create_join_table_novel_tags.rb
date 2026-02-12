class CreateJoinTableNovelTags < ActiveRecord::Migration[8.0]
  def change
    create_join_table :novels, :tags do |t|
      t.index [:novel_id, :tag_id], unique: true
      t.index :tag_id
    end
  end
end