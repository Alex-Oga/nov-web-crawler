class Website < ApplicationRecordhas_rich_text 
    has_rich_text :description
    validates :name, presence: true
end
