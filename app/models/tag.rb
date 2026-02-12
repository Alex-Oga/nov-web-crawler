class Tag < ApplicationRecord
  has_and_belongs_to_many :novels
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  before_validation { self.name = name.to_s.strip.downcase }
end