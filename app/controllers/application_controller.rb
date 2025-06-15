class ApplicationController < ActionController::Base

  include TenantScoped
  include Authentication
  include Authorization
  include ErrorHandling


  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :set_current_tenant
  before_action :configure_permitted_parameters, if: :devise_controller?

  def handle_routing_error
    # Handle the error - you can customize this based on your needs
    render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
  rescue ActionController::MissingTemplate
    # Fallback if 404.html doesn't exist
    render plain: "404 Not Found", status: :not_found
  end

  private

  def configure_permitted_parameters
    # Permit additional fields for sign up
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone])

    # Permit additional fields for account update
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone, :bio, :avatar])
  end
end
