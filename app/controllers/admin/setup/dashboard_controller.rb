class Admin::Setup::DashboardController < Admin::Setup::BaseController
  before_action :set_tenant_context

  def index
    load_setup_overview
  end

  private

  def load_setup_overview
    @setup_stats = {
      staff_members: @tenant.staff_members.count,
      studio_locations: @tenant.studio_locations.count,
      service_packages: @tenant.service_packages.count,
      active_appointments: @tenant.appointments.where('scheduled_at > ?', Time.current).count
    }

    @recent_staff = @tenant.staff_members.order(created_at: :desc).limit(5)
    @recent_locations = @tenant.studio_locations.order(created_at: :desc).limit(3)
    @incomplete_setups = detect_incomplete_setups
  end

  def detect_incomplete_setups
    issues = []

    issues << "No studio locations configured" if @tenant.studio_locations.none?
    issues << "No service packages available" if @tenant.service_packages.none?
    issues << "No staff members added" if @tenant.staff_members.none?
    issues << "Owner account not configured" unless @tenant.tenant_users.where(role: 'owner').exists?

    issues
  end
end
