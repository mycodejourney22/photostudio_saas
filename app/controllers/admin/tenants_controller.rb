class Admin::TenantsController < ApplicationController
  before_action :authenticate_super_admin!
  before_action :set_tenant, only: [:show, :edit, :update, :destroy, :suspend, :activate]

  def index
    @tenants = Tenant.includes(:subscriptions)
                    .page(params[:page])
                    .per(25)
                    .order(:created_at)

    @tenants = @tenants.where(plan_type: params[:plan]) if params[:plan].present?
    @tenants = @tenants.where(status: params[:status]) if params[:status].present?
    @tenants = @tenants.search_scope(params[:search]) if params[:search].present?

    @stats = {
      total_tenants: Tenant.count,
      active_tenants: Tenant.active.count,
      monthly_revenue: Subscription.active.sum(&:monthly_revenue),
      trial_tenants: Tenant.trial.count
    }
  end

  def show
    @subscription = @tenant.subscriptions.active.first
    @usage_stats = TenantUsageService.new(@tenant).calculate_usage
    @recent_activity = @tenant.appointments.recent.limit(10)
  end

  def suspend
    if @tenant.update(status: 'suspended')
      TenantSuspensionJob.perform_async(@tenant.id)
      redirect_to admin_tenant_path(@tenant), notice: 'Tenant suspended successfully.'
    else
      redirect_to admin_tenant_path(@tenant), alert: 'Unable to suspend tenant.'
    end
  end

  def activate
    if @tenant.update(status: 'active')
      redirect_to admin_tenant_path(@tenant), notice: 'Tenant activated successfully.'
    else
      redirect_to admin_tenant_path(@tenant), alert: 'Unable to activate tenant.'
    end
  end

  private

  def authenticate_super_admin!
    redirect_to root_path unless current_user&.super_admin?
  end

  def set_tenant
    @tenant = Tenant.find(params[:id])
  end
end
