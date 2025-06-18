# app/controllers/concerns/authorization.rb
module Authorization
  extend ActiveSupport::Concern

  included do
    include CanCan::ControllerAdditions

    rescue_from CanCan::AccessDenied do |exception|
      # Check if user is authenticated
      if user_signed_in?
        # User is logged in but doesn't have permission
        respond_to do |format|
          format.json { render json: { error: exception.message }, status: :forbidden }
          format.html { redirect_to root_path, alert: exception.message }
        end
      else
        # User is not logged in - redirect to login
        respond_to do |format|
          format.json { render json: { error: 'Authentication required' }, status: :unauthorized }
          format.html {
            store_location_for(:user, request.fullpath) if request.get?
            redirect_to new_user_session_path, alert: 'Please sign in to access this page.'
          }
        end
      end
    end
  end

  private

  def current_ability
    @current_ability ||= Ability.new(current_user, current_tenant)
  end
end
