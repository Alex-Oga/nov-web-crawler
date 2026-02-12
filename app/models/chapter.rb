class Chapter < ApplicationRecord
  belongs_to :novel
  validates :name, uniqueness: { scope: :novel_id }

  scope :ordered, -> { order(position: :asc, created_at: :asc) }

  def previous_chapter
    chs = novel.chapters.order(position: :asc, created_at: :asc).to_a
    idx = chs.index(self)
    return nil unless idx
    chs[idx + 1]
  end

  def next_chapter
    chs = novel.chapters.order(position: :asc, created_at: :asc).to_a
    idx = chs.index(self)
    return nil unless idx && idx > 0
    chs[idx - 1]
  end
end