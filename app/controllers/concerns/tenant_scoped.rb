# app/controllers/concerns/tenant_scoped.rb
module TenantScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_current_tenant
    around_action :with_tenant_scope
    helper_method :current_tenant
  end

  private

  def set_current_tenant
    @current_tenant = TenantResolver.resolve(request)

    if @current_tenant.nil?
      redirect_to_main_site and return
    end

    unless @current_tenant.active?
      redirect_to_tenant_suspended and return
    end

    if user_signed_in? && !current_user.can_access_tenant?(@current_tenant)
      sign_out current_user
      redirect_to new_user_session_path, alert: 'Access denied to this studio'
    end
  end

  def with_tenant_scope(&block)
    ActsAsTenant.with_tenant(@current_tenant, &block)
  end

  def redirect_to_main_site
    if Rails.env.development?
      redirect_to "http://localhost:3000", allow_other_host: true
    else
      redirect_to "https://#{Rails.application.config.main_domain}", allow_other_host: true
    end
  end

  def redirect_to_tenant_suspended
    render 'errors/tenant_suspended', status: :service_unavailable, layout: 'public'
  end

  def current_tenant
    @current_tenant
  end
end
