class CreateSourceLinkAndLinkToNovels < ActiveRecord::Migration[8.0]
  def change
    create_table :sources do |t|
      t.string :name, null:false
      t.string :link
      t.timestamps
    end
    add_index :sources, :link, unique: true
    add_reference :novels, :source, null: true, foreign_key: true
  end
end
