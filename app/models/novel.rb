class Novel < ApplicationRecord
  belongs_to :website
  belongs_to :source, optional: true
  has_many :chapters, dependent: :destroy
  validates :name, uniqueness: { scope: :website_id }
end
