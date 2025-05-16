class CreateWebsites < ActiveRecord::Migration[8.0]
  def change
    create_table :websites do |t|
      t.string :name
      t.string :link
      t.integer :novel_amount

      t.timestamps
    end
  end
end
