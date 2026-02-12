class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  def self.authenticate_by(params)
    email = params[:email_address].to_s.strip.downcase
    user = find_by(email_address: email)
    return nil unless user
    user.authenticate(params[:password]) ? user : nil
  end

  def active_sessions
    sessions.active
  end

  def terminate_all_sessions!
    sessions.destroy_all
  end

  def terminate_other_sessions!(except_session)
    sessions.where.not(id: except_session.id).destroy_all
  end

  def admin?
    admin
  end
end