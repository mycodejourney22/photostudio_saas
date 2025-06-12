class Mobile::CustomersController < ApplicationController
  layout 'mobile'

  def dashboard
    @customer = current_tenant.customers.find_by(email: current_user.email)
    redirect_to mobile_onboarding_path unless @customer

    @next_appointment = @customer.appointments.upcoming.first
    # @recent_photos = @customer.customer_photos.recent.limit(6)
  end

  def appointments
    @customer = current_tenant.customers.find_by(email: current_user.email)
    @appointments = @customer.appointments.includes(:user, :studio).recent
  end

  def book
    @appointment = current_tenant.appointments.build
    @available_slots = AvailabilityService.new(current_tenant).available_slots(Date.current)
  end

  def gallery
    @customer = current_tenant.customers.find_by(email: current_user.email)
    # @photos = @customer.customer_photos.includes(:appointment).recent
  end
end
