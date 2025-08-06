class Website < ApplicationRecord
    has_many :novels, dependent: :destroy

    validates :name, presence: true
end
