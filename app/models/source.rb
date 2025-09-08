class Source < ApplicationRecord
    validates :link, presence: true, uniqueness: true
    validates :name, presence: true, uniqueness: true 
    has_many :novels, dependent: :destroy
end
    