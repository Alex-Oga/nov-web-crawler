class Chapter < ApplicationRecord
  belongs_to :novel
  validates :name, uniqueness: { scope: :novel_id }

  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  def next_chapter
    return nil unless position
    novel.chapters.where("position > ?", position).order(position: :asc).first
  end

  def previous_chapter
    return nil unless position
    novel.chapters.where("position < ?", position).order(position: :desc).first
  end
end