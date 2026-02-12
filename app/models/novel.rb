class Novel < ApplicationRecord
  belongs_to :website
  has_many :chapters, -> { order(position: :asc, created_at: :asc) }, dependent: :destroy
  validates :name, uniqueness: { scope: :website_id }
end