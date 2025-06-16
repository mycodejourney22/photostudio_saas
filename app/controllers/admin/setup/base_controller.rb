class Admin::Setup::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_setup_access!
  layout 'admin/setup'

  protected

  def ensure_setup_access!
    # Check if user can access setup for this tenant
    unless current_user.can_access_setup?(current_tenant)
      redirect_to root_path, alert: 'Access denied. Owner or admin privileges required for setup.'
    end
  end

  def set_tenant_context
    @tenant = current_tenant # Use the current tenant from subdomain
  end
end
