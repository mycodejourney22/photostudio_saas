class DashboardController < ApplicationController
  def index
    @stats = DashboardStats.new(current_tenant, current_user)
    @recent_appointments = current_tenant.appointments
                                        .includes(:customer, :user)
                                        .recent
                                        .limit(5)

    respond_to do |format|
      format.html
      format.json { render json: DashboardSerializer.new(@stats).serializable_hash }
    end
  end
end
