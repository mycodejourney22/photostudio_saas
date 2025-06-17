# app/controllers/public_booking_controller.rb
class PublicBookingController < ActionController::Base
  protect_from_forgery with: :exception
  layout 'public'

  before_action :set_tenant_from_slug
  before_action :set_booking_session
  before_action :set_studio_locations, only: [:index]
  before_action :set_studio_location, only: [:services, :tiers, :calendar, :details, :create]
  before_action :set_service_package, only: [:tiers, :calendar, :details, :create]
  before_action :set_service_tier, only: [:calendar, :details, :create]

  # Step 1: Select Studio Location (Studios only - no packages shown)
  def index
    @studio_locations = @tenant.studio_locations.active.order(:sort_order, :name)

    # If no locations have service packages, show appropriate message
    if @studio_locations.none? { |location| location.service_packages.active.exists? }
      flash.now[:alert] = "No services are currently available for booking. Please contact us directly."
    end
  end

  # Step 2: Select Service Package (for a specific studio)
  def services
    @service_packages = @studio_location.service_packages.active.includes(:service_tiers).order(:sort_order, :name)

    if @service_packages.empty?
      redirect_to public_booking_path(@tenant.subdomain), alert: 'No services available at this location. Please choose a different location or contact us directly.'
      return
    end
  end

  # Step 3: Select Service Tier (for a specific service package)
  def tiers
    @service_tiers = @service_package.service_tiers.active.order(:sort_order, :name)

    if @service_tiers.empty?
      redirect_to public_booking_services_path(@tenant.subdomain, studio_location_id: @studio_location.id),
                  alert: 'No packages available for this service. Please choose a different service.'
      return
    end
  end

  # Step 4: Calendar/Time Selection
  def calendar
    @selected_date = params[:date]&.to_date || Date.current + 1.day
    @available_dates = calculate_available_dates
    @time_slots = calculate_time_slots(@selected_date)

    # Prepare time slots for all available dates for JavaScript
    @time_slots_by_date = {}
    @available_dates.each do |date|
      slots = calculate_time_slots(date)
      @time_slots_by_date[date.to_s] = slots.map do |slot|
        {
          time: slot[:display_time],
          available: slot[:available]
        }
      end
    end

    # Store selections in session
    @booking_session[:studio_location_id] = @studio_location.id
    @booking_session[:service_package_id] = @service_package.id
    @booking_session[:service_tier_id] = @service_tier.id
    @booking_session[:price] = @service_tier.price
    @booking_session[:duration] = @service_tier.duration_minutes
  end

  # Step 5: Customer Details & Payment
  def details
    @selected_slot = params[:slot]
    @selected_date = params[:date]

    unless @selected_slot.present? && @selected_date.present?
      redirect_to public_booking_calendar_path(@tenant.subdomain,
                    studio_location_id: params[:studio_location_id],
                    service_package_id: params[:service_package_id],
                    service_tier_id: params[:service_tier_id]),
                  alert: 'Please select a time slot.'
      return
    end

    # Store slot selection in session
    @booking_session[:selected_slot] = @selected_slot
    @booking_session[:selected_date] = @selected_date

    @customer = Customer.new
    @total_price = @service_tier.price
  end

  def create
    @customer_params = customer_params
    @appointment_params = appointment_params

    # Get booking data from params or session
    @selected_date = params[:date] || @booking_session[:selected_date]
    @selected_slot = params[:slot] || @booking_session[:selected_slot]

    # Find or create customer
    @customer = find_or_create_customer

    if @customer.persisted?
      @appointment = create_appointment

      if @appointment.persisted?
        # Clear booking session
        session[:booking] = {}

        # Redirect to confirmation
        redirect_to public_booking_confirmation_path(@tenant.subdomain, @appointment)
      else
        @total_price = @service_tier.price
        flash.now[:alert] = "There was a problem booking your appointment: #{@appointment.errors.full_messages.join(', ')}"
        render :details, status: :unprocessable_entity
      end
    else
      @total_price = @service_tier.price
      render :details, status: :unprocessable_entity
    end
  end

  def confirmation
    @appointment = @tenant.appointments.find(params[:appointment_id])
    @customer = @appointment.customer
    @service_tier = @appointment.service_tier
    @service_package = @appointment.service_package
    @studio_location = @appointment.studio_location
  rescue ActiveRecord::RecordNotFound
    redirect_to public_booking_path(@tenant.subdomain), alert: 'Appointment not found.'
  end

  def payment_callback
    reference = params[:reference]

    if reference.present?
      # Find appointment by payment reference
      @appointment = @tenant.appointments.find_by(payment_reference: reference)

      if @appointment
        # Verify payment with your payment provider here
        # For example, if using Paystack:
        # payment_verified = verify_payment(reference)

        # For now, assuming payment is verified
        @appointment.update!(status: 'confirmed', payment_status: 'paid')

        redirect_to public_booking_confirmation_path(@tenant.subdomain, @appointment),
                    notice: 'Payment successful! Your appointment is confirmed. Check your email for details.'
      else
        redirect_to public_booking_path(@tenant.subdomain), alert: 'Appointment not found.'
      end
    else
      redirect_to public_booking_path(@tenant.subdomain), alert: 'Invalid payment reference.'
    end
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
    location_id = params[:studio_location_id] || @booking_session[:studio_location_id]
    @studio_location = @tenant.studio_locations.find_by!(id: location_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to public_booking_path(@tenant.subdomain), alert: 'Studio location not found.'
  end

  def set_service_package
    package_id = params[:service_package_id] || @booking_session[:service_package_id]
    @service_package = @studio_location.service_packages.find_by!(id: package_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to public_booking_services_path(@tenant.subdomain, studio_location_id: @studio_location.id),
                alert: 'Service not found.'
  end

  def set_service_tier
    tier_id = params[:service_tier_id] || @booking_session[:service_tier_id]
    @service_tier = @service_package.service_tiers.active.find(tier_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to public_booking_tiers_path(@tenant.subdomain,
                  studio_location_id: @studio_location.id,
                  service_package_id: @service_package.id),
                alert: 'Service tier not found.'
  end

  def calculate_available_dates
    start_date = Date.current + 1.day
    end_date = start_date + @studio_location.advance_booking_days.to_i.days

    available_dates = []
    (start_date..end_date).each do |date|
      next unless @studio_location.open_on_day?(date.strftime('%A').downcase)

      # Check if location has availability
      if has_availability_on_date?(date)
        available_dates << date
      end
    end

    available_dates.first(30) # Limit to 30 days
  end

  def calculate_time_slots(date)
    return [] unless @studio_location.open_on_day?(date.strftime('%A').downcase)

    operating_hours = @studio_location.operating_hours_for_day(date.strftime('%A').downcase)
    start_time = Time.parse("#{date} #{operating_hours['start']}")
    end_time = Time.parse("#{date} #{operating_hours['end']}")

    slots = []
    current_time = start_time
    slot_duration = @service_tier.duration_minutes
    buffer_time = @studio_location.booking_buffer_minutes.to_i

    while current_time + slot_duration.minutes <= end_time
      slot_end_time = current_time + slot_duration.minutes

      if slot_available?(current_time, slot_end_time)
        slots << {
          time: current_time,
          display_time: current_time.strftime('%I:%M %p'),
          end_time: slot_end_time,
          available: true
        }
      end

      current_time += (slot_duration + buffer_time).minutes
    end

    slots
  end

  def has_availability_on_date?(date)
    booked_count = @tenant.appointments
                          .where(studio_location: @studio_location)
                          .where(scheduled_at: date.all_day)
                          .where.not(status: 'cancelled')
                          .count

    max_bookings = @studio_location.max_daily_bookings.to_i
    max_bookings = 10 if max_bookings.zero? # Default fallback

    booked_count < max_bookings
  end

  def slot_available?(start_time, end_time)
    # Get all non-cancelled appointments for this location on the selected date
    appointments_on_date = @tenant.appointments
                                  .where(studio_location: @studio_location)
                                  .where.not(status: 'cancelled')
                                  .where(scheduled_at: start_time.beginning_of_day..start_time.end_of_day)

    # Check each appointment for time conflicts using Ruby
    appointments_on_date.none? do |appointment|
      existing_start = appointment.scheduled_at
      existing_end = existing_start + appointment.duration_minutes.minutes

      # Check for any overlap
      (start_time < existing_end) && (end_time > existing_start)
    end
  end

  def find_or_create_customer
    customer = @tenant.customers.find_by(email: @customer_params[:email])

    if customer
      customer.update(@customer_params)
      customer
    else
      @tenant.customers.create(@customer_params)
    end
  end

  def create_appointment
    # Use instance variables
    selected_date = @selected_date
    selected_slot = @selected_slot

    # Validate inputs
    unless selected_date.present? && selected_slot.present?
      Rails.logger.error "Missing booking data: date=#{selected_date.inspect}, slot=#{selected_slot.inspect}"
      raise ArgumentError, "Missing date or slot information"
    end

    slot_time = Time.parse("#{selected_date} #{selected_slot}")

    # For public bookings, use the tenant's system user
    system_user = @tenant.system_user

    appointment = @tenant.appointments.create!(
      customer: @customer,
      user: system_user,
      studio_location: @studio_location,
      service_tier: @service_tier,
      service_package_id: @service_package.id,
      scheduled_at: slot_time,
      duration_minutes: @service_tier.duration_minutes,
      price: @service_tier.price,
      session_type: @service_package.category,
      status: 'pending',
      payment_status: 'unpaid',
      booking_source: 'online',
      notes: @appointment_params[:notes],
      special_requirements: @appointment_params[:special_requirements]
    )

    # Return the appointment object
    appointment

  rescue ActiveRecord::RecordInvalid => e
    # Return the invalid appointment object with errors
    Rails.logger.error("Appointment creation failed: #{e.record.errors.full_messages.join(', ')}")
    e.record
  end

  def generate_payment_reference
    "PAY_#{Time.current.to_i}_#{SecureRandom.hex(4).upcase}"
  end

  def customer_params
    params.require(:customer).permit(:first_name, :last_name, :email, :phone, :notes)
  end

  def appointment_params
    selected_date = params[:date] || @booking_session[:selected_date]
    selected_slot = params[:slot] || @booking_session[:selected_slot]

    params.require(:appointment).permit(:special_requests, :special_requirements, :notes).merge(
      scheduled_at: DateTime.parse("#{selected_date} #{selected_slot}"),
      duration_minutes: @service_tier.duration_minutes
    )
  end
end
