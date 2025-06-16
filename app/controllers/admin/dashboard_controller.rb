class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_super_admin!
  layout 'admin'

  def index
    @stats = {
      total_tenants: Tenant.count,
      active_tenants: Tenant.where(status: 'active').count,
      total_users: User.count,
      super_admins: User.super_admins.count
    }

    @recent_tenants = Tenant.order(created_at: :desc).limit(5)
    @recent_users = User.order(created_at: :desc).limit(5)
  end

  def system_stats
    render json: {
      tenants: {
        total: Tenant.count,
        active: Tenant.where(status: 'active').count,
        trial: Tenant.where(status: 'trial').count,
        suspended: Tenant.where(status: 'suspended').count
      },
      users: {
        total: User.count,
        active: User.where(active: true).count,
        super_admins: User.super_admins.count
      }
    }
  end

  private

  def ensure_super_admin!
    unless current_user.super_admin?
      redirect_to root_path, alert: 'Access denied. Super admin privileges required.'
    end
  end
end
