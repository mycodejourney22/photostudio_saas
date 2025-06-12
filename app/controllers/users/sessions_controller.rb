# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  include TenantScoped

  # IMPORTANT: Skip authentication for login pages
  skip_before_action :authenticate_user!

  layout 'public'

  def new
    super
  end

  def create
    super
  end

  def destroy
    super
  end

  protected

  def after_sign_in_path_for(resource)
    # Check if user can access current tenant
    if current_tenant && resource.can_access_tenant?(current_tenant)
      dashboard_path
    elsif resource.primary_tenant
      # Return URL string for redirect to user's primary tenant
      if Rails.env.development?
        "http://#{resource.primary_tenant.subdomain}.localhost:3000/dashboard"
      else
        "https://#{resource.primary_tenant.subdomain}.#{Rails.application.config.app_domain}/dashboard"
      end
    else
      # Return URL string for redirect to main site
      if Rails.env.development?
        "http://localhost:3000"
      else
        "https://#{Rails.application.config.main_domain}"
      end
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    if current_tenant
      new_user_session_path
    else
      if Rails.env.development?
        "http://localhost:3000"
      else
        "https://#{Rails.application.config.main_domain}"
      end
    end
  end

  private

  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [:email, :password, :remember_me])
  end
end
