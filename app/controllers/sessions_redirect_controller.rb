# app/controllers/sessions_redirect_controller.rb
class SessionsRedirectController < ApplicationController
    layout 'public' # if you're using a separate layout for landing pages

    skip_before_action :set_current_tenant
    skip_before_action :authenticate_user!
  
    def new
    end
  
    def create
      identifier = params[:identifier].to_s.strip.downcase
  
      tenant = if identifier.include?('@')
        user = User.find_by(email: identifier)
        user&.primary_tenant
      else
        Tenant.find_by(subdomain: identifier)
      end
  
      if tenant.present?
        redirect_to login_url_for(tenant)
      else
        flash.now[:alert] = "We couldn't find your account. Please check and try again."
        render :new, status: :unprocessable_entity
      end
    end
  
    private
  
    def login_url_for(tenant)
      protocol = Rails.env.development? ? 'http' : 'https'
      domain   = Rails.env.development? ? 'localhost:3000' : Rails.application.config.app_domain
      "#{protocol}://#{tenant.subdomain}.#{domain}/users/sign_in"
    end
end
  