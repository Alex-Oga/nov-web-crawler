class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  
  def active_sessions
    sessions.active
  end
  
  def terminate_all_sessions!
    sessions.destroy_all
  end
  
  def terminate_other_sessions!(except_session)
    sessions.where.not(id: except_session.id).destroy_all
  end
end