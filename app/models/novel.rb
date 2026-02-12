class Novel < ApplicationRecord
  belongs_to :website
  has_many :chapters, -> { order(position: :asc, created_at: :asc) }, dependent: :destroy

  validates :name, uniqueness: { scope: :website_id }

  has_and_belongs_to_many :tags

  # Return tags as comma separated list for forms
  def tag_list
    tags.pluck(:name).join(', ')
  end

  # Accepts comma-separated or array
  def tag_list=(value)
    names = Array(value).join(',').split(',').map { |n| n.to_s.strip.downcase }.reject(&:blank?).uniq
    self.tags = names.map { |n| Tag.find_or_create_by!(name: n) }
  end

  # Scopes for searching
  scope :with_any_tags, ->(names) {
    names = Array(names).map(&:to_s).map(&:strip).map(&:downcase).reject(&:blank?)
    return none if names.empty?
    joins(:tags).where(tags: { name: names }).distinct
  }

  scope :with_all_tags, ->(names) {
    names = Array(names).map(&:to_s).map(&:strip).map(&:downcase).reject(&:blank?)
    return none if names.empty?
    joins(:tags)
      .where(tags: { name: names })
      .group('novels.id')
      .having('COUNT(DISTINCT tags.id) = ?', names.length)
  }
end