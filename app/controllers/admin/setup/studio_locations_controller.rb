class Admin::Setup::StudioLocationsController < Admin::Setup::BaseController
  before_action :set_tenant_context
  before_action :ensure_tenant_selected
  before_action :set_studio_location, only: [:show, :edit, :update, :destroy, :toggle_status]

  def index
    @studio_locations = @tenant.studio_locations.order(:sort_order, :name)
    @studio_locations = @studio_locations.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
  end

  def new
    @studio_location = @tenant.studio_locations.build
    build_default_operating_hours
  end

  def create
    @studio_location = @tenant.studio_locations.build(studio_location_params)

    if @studio_location.save
      redirect_to admin_setup_studio_locations_path(tenant_id: @tenant.id), notice: 'Studio location created successfully.'
    else
      build_default_operating_hours
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def show
  end

  def toggle_status
  end

  def update
    if @studio_location.update(studio_location_params)
      redirect_to admin_setup_studio_locations_path(tenant_id: @tenant.id), notice: 'Studio location updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if can_delete_location?
      @studio_location.destroy
      redirect_to admin_setup_studio_locations_path(tenant_id: @tenant.id), notice: 'Studio location removed successfully.'
    else
      redirect_to admin_setup_studio_locations_path(tenant_id: @tenant.id), alert: 'Cannot delete location with existing appointments.'
    end
  end

  def toggle_status
    @studio_location.update(active: !@studio_location.active?)
    status = @studio_location.active? ? 'activated' : 'deactivated'
    redirect_to admin_setup_studio_locations_path(tenant_id: @tenant.id), notice: "Studio location #{status} successfully."
  end

  private

  def ensure_tenant_selected
    unless @tenant
      redirect_to admin_setup_root_path, alert: 'Please select a tenant to manage studio locations.'
    end
  end

  def set_studio_location
    @studio_location = @tenant.studio_locations.find(params[:id])
  end

  def studio_location_params
    params.require(:studio_location).permit(
      :name, :address, :city, :state, :postal_code, :phone,
      :description, :default_slot_duration, :sort_order,
      operating_hours: {},
      booking_settings: {},
      metadata: {}
    )
  end

  def build_default_operating_hours
    @studio_location.operating_hours ||= {
      'monday' => { 'start' => '09:00', 'end' => '17:00' },
      'tuesday' => { 'start' => '09:00', 'end' => '17:00' },
      'wednesday' => { 'start' => '09:00', 'end' => '17:00' },
      'thursday' => { 'start' => '09:00', 'end' => '17:00' },
      'friday' => { 'start' => '09:00', 'end' => '17:00' },
      'saturday' => { 'start' => '10:00', 'end' => '16:00' },
      'sunday' => { 'start' => '', 'end' => '' }
    }

    @studio_location.booking_settings ||= {
      'buffer_time' => 15,
      'advance_booking_days' => 30,
      'max_daily_bookings' => 8
    }
  end

  def can_delete_location?
    # Check if location has any appointments
    @tenant.appointments.where(studio_location: @studio_location).none?
  end
end
