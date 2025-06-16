# app/controllers/admin/tenants_controller.rb
class Admin::TenantsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_super_admin!
  before_action :set_tenant, only: [:show, :edit, :update, :destroy, :suspend, :activate, :usage_stats, :update_plan]

  # Skip tenant scoped checks for super admins
  skip_before_action :set_current_tenant

  layout 'admin'

  def index
    @tenants = Tenant.all.order(:name)
    @tenants = @tenants.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @tenants = @tenants.where(status: params[:status]) if params[:status].present?
  end

  def show
    @tenant_stats = {
      users: @tenant.users.count,
      staff: @tenant.staff_members.count,
      appointments: @tenant.appointments.count,
      revenue: @tenant.sales.sum(:total_amount)
    }
  end

  def new
    @tenant = Tenant.new
  end

  def create
    @tenant = Tenant.new(tenant_params)

    if @tenant.save
      redirect_to admin_tenant_path(@tenant), notice: 'Tenant created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tenant.update(tenant_params)
      redirect_to admin_tenant_path(@tenant), notice: 'Tenant updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @tenant.can_be_deleted?
      @tenant.destroy
      redirect_to admin_tenants_path, notice: 'Tenant deleted successfully.'
    else
      redirect_to admin_tenant_path(@tenant), alert: 'Cannot delete tenant with existing data.'
    end
  end

  def suspend
    @tenant.update!(status: 'suspended')
    redirect_to admin_tenant_path(@tenant), notice: 'Tenant suspended successfully.'
  end

  def activate
    @tenant.update!(status: 'active')
    redirect_to admin_tenant_path(@tenant), notice: 'Tenant activated successfully.'
  end

  def usage_stats
    render json: {
      users: @tenant.users.count,
      appointments: @tenant.appointments.count,
      storage_used: calculate_storage_usage(@tenant)
    }
  end

  def update_plan
    if @tenant.update(plan_type: params[:plan_type])
      redirect_to admin_tenant_path(@tenant), notice: 'Plan updated successfully.'
    else
      redirect_to admin_tenant_path(@tenant), alert: 'Failed to update plan.'
    end
  end

  private

  def set_tenant
    @tenant = Tenant.find(params[:id])
  end

  def tenant_params
    params.require(:tenant).permit(:name, :email, :plan_type, :status, metadata: {})
  end

  def ensure_super_admin!
    unless current_user.super_admin?
      redirect_to root_path, alert: 'Access denied. Super admin privileges required.'
    end
  end

  def calculate_storage_usage(tenant)
    # Implement storage calculation logic
    0
  end
end
