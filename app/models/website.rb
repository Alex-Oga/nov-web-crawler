class Website < ApplicationRecord
    has_many :novels, dependent: :destroy
    has_one_attached :featured_image
    has_rich_text :description

    validates :name, presence: true
    validates :novel_amount, numericality: { greater_than_or_equal_to: 0 }
end
