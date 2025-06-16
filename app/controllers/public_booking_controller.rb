# app/controllers/public_booking_controller.rb
class PublicBookingController < ActionController::Base
  protect_from_forgery with: :exception
  layout 'public'

  before_action :set_tenant_from_slug
  before_action :set_booking_session
  before_action :set_studio_locations, only: [:index]
  before_action :set_studio_location, except: [:index, :confirmation]
  before_action :set_service_packages, only: [:packages]
  before_action :set_service_package, only: [:tiers, :slots, :details, :create]
  before_action :set_service_tier, only: [:slots, :details, :create]

  # Step 1: Select Studio Location
  def index
    @studio_locations = @tenant.studio_locations.active.order(:sort_order, :name)

    # Only auto-redirect if there's exactly one location AND it has service packages
    if @studio_locations.count == 1
      location = @studio_locations.first
      if location.service_packages.active.exists?
        redirect_to public_booking_services_path(@tenant.subdomain)
        return
      end
    end

    # If no locations have service packages, show appropriate message
    if @studio_locations.none? { |location| location.service_packages.active.exists? }
      flash.now[:alert] = "No services are currently available for booking. Please contact us directly."
    end
  end

  def services
    @service_packages = @tenant.service_packages.active.includes(:service_tiers).order(:sort_order, :name)

    if @service_packages.empty?
      redirect_to public_booking_path(@tenant.subdomain), alert: 'No services available. Please contact us directly.'
      return
    end
  end

  def calendar
    # Implementation for calendar view
    render plain: "Calendar view - Coming soon"
  end

  def details
    # Implementation for booking details
    render plain: "Details view - Coming soon"
  end

  def create
    # Implementation for creating booking
    render plain: "Create booking - Coming soon"
  end

  def confirmation
    # Implementation for confirmation
    render plain: "Confirmation - Coming soon"
  end

  private

  def set_tenant_from_slug
    @tenant = Tenant.find_by!(subdomain: params[:tenant_slug], status: 'active')
  rescue ActiveRecord::RecordNotFound
    redirect_to root_url, alert: 'Studio not found or not available.'
  end

  def set_booking_session
    session[:booking] ||= {}
    @booking_session = session[:booking]
  end

  def set_studio_locations
    @studio_locations = @tenant.studio_locations.active.order(:sort_order, :name)
  end

  def set_studio_location
    @studio_location = @tenant.studio_locations.find_by!(id: params[:studio_location_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to public_booking_path(@tenant.subdomain), alert: 'Studio location not found.'
  end

  def set_service_packages
    @service_packages = @studio_location.service_packages.active
  end

  def set_service_package
    @service_package = @tenant.service_packages.find_by!(slug: params[:service_package_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to public_booking_services_path(@tenant.subdomain), alert: 'Service not found.'
  end

  def set_service_tier
    @service_tier = @service_package.service_tiers.active.find(params[:service_tier_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to public_booking_services_path(@tenant.subdomain), alert: 'Service tier not found.'
  end
end
