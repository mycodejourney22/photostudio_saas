module Authorization
  extend ActiveSupport::Concern

  included do
    include CanCan::ControllerAdditions

    rescue_from CanCan::AccessDenied do |exception|
      respond_to do |format|
        format.json { render json: { error: exception.message }, status: :forbidden }
        format.html { redirect_to root_path, alert: exception.message }
      end
    end
  end

  private

  def current_ability
    @current_ability ||= Ability.new(current_user, current_tenant)
  end
end
