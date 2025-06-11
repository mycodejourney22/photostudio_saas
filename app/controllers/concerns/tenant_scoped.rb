module TenantScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_current_tenant
    around_action :with_tenant_scope
  end

  private

  def set_current_tenant
    @current_tenant = TenantResolver.resolve(request)

    if @current_tenant.nil?
      redirect_to_main_site and return
    end

    unless current_user&.can_access_tenant?(@current_tenant)
      redirect_to root_path, alert: 'Access denied'
    end
  end

  def with_tenant_scope(&block)
    ActsAsTenant.with_tenant(@current_tenant, &block)
  end

  def redirect_to_main_site
    redirect_to "https://#{Rails.application.config.main_domain}"
  end

  def current_tenant
    @current_tenant
  end

  helper_method :current_tenant
end
