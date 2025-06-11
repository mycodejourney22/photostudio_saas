class ApplicationController < ActionController::Base

  include TenantScoped
  include Authentication
  include Authorization
  include ErrorHandling


  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :set_current_tenant
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  def configure_permitted_parameters
    # Permit additional fields for sign up
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone])

    # Permit additional fields for account update
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone, :bio, :avatar])
  end
end
