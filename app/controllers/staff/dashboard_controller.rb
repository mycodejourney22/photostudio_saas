class Staff::DashboardController < ApplicationController
  before_action :authenticate_staff!

  def index
    @today_appointments = current_user.appointments
                                     .includes(:customer, :studio)
                                    .today
                                     .order(:scheduled_at)
    @stats = {
      today_sessions: @today_appointments.count,
      today_revenue: @today_appointments.sum(:price),
      pending_appointments: current_user.appointments.pending.count
    }

    respond_to do |format|
      format.html
      format.json { render json: { appointments: @today_appointments, stats: @stats } }
    end
  end

  private

  def authenticate_staff!
    return if current_user&.role_in_tenant(current_tenant).in?(['admin', 'staff', 'owner'])

    redirect_to root_path, alert: 'Staff access required'
  end
end
