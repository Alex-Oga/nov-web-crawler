class Chapter < ApplicationRecord
  belongs_to :novel
  validates :name, uniqueness: { scope: :novel_id }
end
