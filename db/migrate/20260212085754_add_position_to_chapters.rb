class AddPositionToChapters < ActiveRecord::Migration[8.0]
  def up
    add_column :chapters, :position, :integer

    say_with_time "Backfilling chapter positions per novel" do
      Novel.find_each do |novel|
        novel.chapters.order(:created_at).each_with_index do |ch, idx|
          ch.update_columns(position: idx + 1)
        end
      end
    end

    add_index :chapters, [:novel_id, :position]
  end
end