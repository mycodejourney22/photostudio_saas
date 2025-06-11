module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    return if user_signed_in?

    if request.format.json?
      render json: { error: 'Authentication required' }, status: :unauthorized
    else
      redirect_to new_user_session_path
    end
  end

  def authenticate_admin!
    return if current_user&.role_in_tenant(current_tenant) == 'admin'

    redirect_to root_path, alert: 'Admin access required'
  end

  def authenticate_owner!
    return if current_user&.role_in_tenant(current_tenant) == 'owner'

    redirect_to root_path, alert: 'Owner access required'
  end
end
