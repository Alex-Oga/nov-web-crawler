class CreateNovels < ActiveRecord::Migration[8.0]
  def change
    create_table :novels do |t|
      t.belongs_to :website, null: false, foreign_key: true
      t.string :link

      t.timestamps
    end
  end
end
