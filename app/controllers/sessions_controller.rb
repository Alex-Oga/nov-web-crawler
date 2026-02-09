class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      session_record = start_new_session_for(user)
      
      Rails.logger.info "New session created for user #{user.email_address} (Session ID: #{session_record.id})"
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    Rails.logger.info "Session terminated for user #{current_user&.email_address}"
    terminate_session
    redirect_to new_session_path, notice: "You have been logged out."
  end
end