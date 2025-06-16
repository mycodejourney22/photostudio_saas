class Admin::Setup::ServiceTiersController < Admin::Setup::BaseController
  before_action :set_tenant_context
  before_action :set_service_package
  before_action :set_service_tier, only: [:show, :edit, :update, :destroy]

  def new
    @service_tier = @service_package.service_tiers.build
  end

  def create
    @service_tier = @service_package.service_tiers.build(service_tier_params)

    if @service_tier.save
      redirect_to admin_setup_services_path(tenant_id: @tenant.id), notice: 'Service tier created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @service_tier.update(service_tier_params)
      redirect_to admin_setup_services_path(tenant_id: @tenant.id), notice: 'Service tier updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def show
  end

  def destroy
    if can_delete_tier?
      @service_tier.destroy
      redirect_to admin_setup_services_path(tenant_id: @tenant.id), notice: 'Service tier removed successfully.'
    else
      redirect_to admin_setup_services_path(tenant_id: @tenant.id), alert: 'Cannot delete service tier with existing bookings.'
    end
  end

  private

  def set_service_package
    @service_package = @tenant.service_packages.find_by!(slug: params[:service_id])
  end

  def set_service_tier
    @service_tier = @service_package.service_tiers.find(params[:id])
  end

  def service_tier_params
    params.require(:service_tier).permit(
      :name, :description, :price, :duration_minutes, :sort_order,
      features: [], metadata: {}
    )
  end

  def can_delete_tier?
    @service_tier.appointments.none?
  end
end
