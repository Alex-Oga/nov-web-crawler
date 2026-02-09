module Authentication
  extend ActiveSupport::Concern
  
  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user
  end
  
  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def require_authentication
      unless authenticated?
        redirect_to new_session_path
      end
    end

    def authenticated?
      find_session_by_cookie.present?
    end

    def current_user
      @current_user ||= find_session_by_cookie&.user
    end

    def find_session_by_cookie
      return @current_session if defined?(@current_session)
      
      session_token = cookies.signed[:session_token]
      return @current_session = nil unless session_token
      
      @current_session = Session.includes(:user).find_by_token(session_token)
      
      # Check if session exists and is not expired
      if @current_session&.expired?
        @current_session.destroy
        cookies.delete(:session_token)
        @current_session = nil
      elsif @current_session
        # Touch session activity to extend expiration
        @current_session.touch_activity!
      end
      
      @current_session
    end

    def start_new_session_for(user)
      # Clean up any existing sessions for this user if needed
      cleanup_old_sessions_for(user)
      
      session = user.sessions.create!(
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      
      cookies.signed.permanent[:session_token] = {
        value: session.session_token,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax
      }
      
      session
    end

    def terminate_session
      if current_session = find_session_by_cookie
        current_session.destroy
      end
      cookies.delete(:session_token)
      @current_session = nil
      @current_user = nil
    end
    
    def cleanup_old_sessions_for(user)
      # More efficient: delete old sessions in a single query
      old_session_ids = user.sessions.active
                           .order(created_at: :desc)
                           .offset(5)
                           .pluck(:id)
      
      if old_session_ids.any?
        Session.where(id: old_session_ids).delete_all
      end
    end

    def after_authentication_url
      session.delete(:return_to_after_authentication) || root_url
    end

    def resume_session_url
      session[:return_to_after_authentication] = request.url
    end
end