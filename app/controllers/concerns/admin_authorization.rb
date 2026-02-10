module AdminAuthorization
  extend ActiveSupport::Concern

  private

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end

  def admin_only_actions(*actions)
    before_action :require_admin, only: actions
  end
end