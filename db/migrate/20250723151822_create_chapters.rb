class CreateChapters < ActiveRecord::Migration[8.0]
  def change
    create_table :chapters do |t|
      t.belongs_to :novel, null: false, foreign_key: true
      t.string :name
      t.string :link
      t.text :content

      t.timestamps
    end
  end
end
