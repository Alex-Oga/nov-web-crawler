class Session < ApplicationRecord
  belongs_to :user
  
  # Session expires after 30 days of inactivity
  EXPIRY_TIME = 30.days
  
  before_validation :generate_session_token, on: :create
  before_validation :set_expires_at, on: :create
  
  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  
  validates :session_token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  
  def expired?
    expires_at <= Time.current
  end
  
  def touch_activity!
    update!(expires_at: EXPIRY_TIME.from_now)
  end
  
  def self.find_by_token(token)
    find_by(session_token: token)
  end
  
  def self.cleanup_expired
    expired.destroy_all
  end
  
  private
  
  def generate_session_token
    return if session_token.present?
    
    loop do
      token = SecureRandom.urlsafe_base64(32)
      break self.session_token = token unless Session.exists?(session_token: token)
    end
  end
  
  def set_expires_at
    self.expires_at = EXPIRY_TIME.from_now if expires_at.blank?
  end
end