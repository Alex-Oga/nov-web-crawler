class SessionCleanupJob < ApplicationJob
  queue_as :default
  
  def perform
    cleaned_count = Session.cleanup_expired
    Rails.logger.info "Cleaned up #{cleaned_count} expired sessions"
  end
end