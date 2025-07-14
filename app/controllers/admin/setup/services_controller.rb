class Admin::Setup::ServicesController < Admin::Setup::BaseController
  before_action :set_tenant_context
  before_action :ensure_tenant_selected
  before_action :set_service_package, only: [:show, :edit, :update, :destroy, :toggle_status]

  def index
    @service_packages = @tenant.service_packages.includes(:service_tiers).order(:sort_order, :name)
    @service_packages = @service_packages.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @service_packages = @service_packages.where(category: params[:category]) if params[:category].present?
  end

  def new
    @service_package = @tenant.service_packages.build
    @available_categories = ServicePackage::CATEGORIES
    @studio_locations = @tenant.studio_locations.active.order(:name)
  end

  def create
    @service_package = @tenant.service_packages.build(service_package_params)
    @service_package.name = params["service_package"]["category"]
    if @service_package.save
      handle_studio_location_assignments
      redirect_to admin_setup_services_path(tenant_id: @tenant.id), notice: 'Service package created successfully.'
    else
      @available_categories = ServicePackage::CATEGORIES
      @studio_locations = @tenant.studio_locations.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def toggle_status
  end

  def edit
    @available_categories = ServicePackage::CATEGORIES
    @studio_locations = @tenant.studio_locations.active.order(:name)
  end

  def update
    if @service_package.update(service_package_params)
      handle_studio_location_assignments
      redirect_to admin_setup_services_path(tenant_id: @tenant.id), notice: 'Service package updated successfully.'
    else
      @available_categories = ServicePackage::CATEGORIES
      @studio_locations = @tenant.studio_locations.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if can_delete_service?
      @service_package.destroy
      redirect_to admin_setup_services_path(tenant_id: @tenant.id), notice: 'Service package removed successfully.'
    else
      redirect_to admin_setup_services_path(tenant_id: @tenant.id), alert: 'Cannot delete service package with existing bookings.'
    end
  end

  def toggle_status
    @service_package.update(active: !@service_package.active?)
    status = @service_package.active? ? 'activated' : 'deactivated'
    redirect_to admin_setup_services_path(tenant_id: @tenant.id), notice: "Service package #{status} successfully."
  end

  private

  def ensure_tenant_selected
    unless @tenant
      redirect_to admin_setup_root_path, alert: 'Please select a tenant to manage services.'
    end
  end

  def set_service_package
    @service_package = @tenant.service_packages.find(params[:id])
  end

  def service_package_params
    params.require(:service_package).permit(
      :name,
      :slug,
      :description,
      :category,
      :sort_order,
      :photo,                        
      metadata: {},
      studio_location_ids: []
    )
  end

  def handle_studio_location_assignments
    if params[:service_package][:studio_location_ids].present?
      studio_location_ids = params[:service_package][:studio_location_ids].reject(&:blank?)
      @service_package.studio_location_ids = studio_location_ids
    end
  end

  def can_delete_service?
    # Check if service package has any bookings through service tiers
    @service_package.service_tiers.joins(:appointments).none?
  end
end
