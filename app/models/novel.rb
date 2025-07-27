class Novel < ApplicationRecord
  belongs_to :website
  has_many :chapters, dependent: :destroy
end
