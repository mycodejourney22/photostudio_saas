# app/controllers/booking_controller.rb
class BookingController < ApplicationController
  skip_before_action :authenticate_user! # Allow public booking
  layout 'public'

  before_action :set_booking_session
  before_action :set_studio_locations, only: [:index, :location]
  before_action :set_studio_location, except: [:index]
  before_action :set_service_packages, only: [:packages]
  before_action :set_service_package, only: [:tiers, :slots, :details, :create]
  before_action :set_service_tier, only: [:slots, :details, :create]

  # Step 1: Select Studio Location
  def index
    @studio_locations = current_tenant.studio_locations.active.ordered
    redirect_to booking_location_path(@studio_locations.first) if @studio_locations.count == 1
  end

  # Step 2: Select Service Package
  def packages
    @service_packages = @studio_location.available_packages

    if @service_packages.empty?
      redirect_to booking_path, alert: 'No services available at this location.'
      return
    end

    # Auto-select if only one package
    redirect_to booking_tiers_path(@studio_location, @service_packages.first) if @service_packages.count == 1
  end

  # Step 3: Select Service Tier
  def tiers
    @service_tiers = @service_package.active_tiers

    if @service_tiers.empty?
      redirect_to booking_packages_path(@studio_location), alert: 'No tiers available for this service.'
      return
    end
  end

  # Step 4: Select Time Slot
  def slots
    @selected_date = params[:date]&.to_date || Date.current + 1.day
    @available_dates = calculate_available_dates
    @time_slots = calculate_time_slots(@selected_date)

    # Store tier selection in session
    @booking_session[:service_tier_id] = @service_tier.id
    @booking_session[:price] = @service_tier.price
    @booking_session[:duration] = @service_tier.duration_minutes
  end

  # Step 5: Customer Details & Payment
  def details
    @selected_slot = params[:slot]

    unless @selected_slot.present?
      redirect_to booking_slots_path(@studio_location, @service_package, @service_tier),
                  alert: 'Please select a time slot.'
      return
    end

    # Store slot selection
    @booking_session[:selected_slot] = @selected_slot
    @booking_session[:selected_date] = params[:date]

    @customer = Customer.new
    @total_price = @service_tier.price
  end

  # Step 6: Create Appointment & Process Payment
  def create
    @customer_params = customer_params
    @appointment_params = appointment_params

    # Find or create customer
    @customer = find_or_create_customer

    if @customer.persisted?
      @appointment = create_appointment

      if @appointment.persisted?
        # Process payment
        process_payment
      else
        render :details, status: :unprocessable_entity
      end
    else
      render :details, status: :unprocessable_entity
    end
  end

  # Confirmation page
  def confirmation
    @appointment = current_tenant.appointments.find(params[:appointment_id])

    # Clear booking session
    session.delete(:booking)

    # Ensure only confirmed appointments can be viewed
    unless @appointment.confirmed? || @appointment.paid?
      redirect_to booking_path, alert: 'Appointment not found or not confirmed.'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to booking_path, alert: 'Appointment not found.'
  end

  private

  def set_booking_session
    session[:booking] ||= {}
    @booking_session = session[:booking]
  end

  def set_studio_locations
    @studio_locations = current_tenant.studio_locations.active.ordered
  end

  def set_studio_location
    @studio_location = current_tenant.studio_locations.find_by!(id: params[:studio_location_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to booking_path, alert: 'Studio location not found.'
  end

  def set_service_packages
    @service_packages = @studio_location.available_packages
  end

  def set_service_package
    @service_package = @studio_location.service_packages
                                      .find_by!(slug: params[:service_package_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to booking_packages_path(@studio_location), alert: 'Service not found.'
  end

  def set_service_tier
    @service_tier = @service_package.service_tiers.active.find(params[:service_tier_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to booking_tiers_path(@studio_location, @service_package), alert: 'Service tier not found.'
  end

  def calculate_available_dates
    start_date = Date.current + 1.day
    end_date = start_date + @studio_location.advance_booking_days.days

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
    buffer_time = @studio_location.booking_buffer_minutes

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
    booked_count = current_tenant.appointments
                                .where(studio_location: @studio_location)
                                .where(scheduled_at: date.all_day)
                                .where.not(status: 'cancelled')
                                .count

    booked_count < @studio_location.max_daily_bookings
  end

  def slot_available?(start_time, end_time)
    conflicting_appointments = current_tenant.appointments
                                           .where(studio_location: @studio_location)
                                           .where.not(status: 'cancelled')
                                           .where(
                                             '(scheduled_at <= ? AND scheduled_at + INTERVAL duration_minutes MINUTE > ?) OR ' \
                                             '(scheduled_at < ? AND scheduled_at + INTERVAL duration_minutes MINUTE >= ?)',
                                             start_time, start_time, end_time, end_time
                                           )

    conflicting_appointments.empty?
  end

  def find_or_create_customer
    existing_customer = current_tenant.customers.find_by(email: @customer_params[:email])

    if existing_customer
      existing_customer.update(@customer_params)
      existing_customer
    else
      current_tenant.customers.create(@customer_params.merge(active: true))
    end
  end

  def create_appointment
    slot_time = Time.parse("#{@booking_session[:selected_date]} #{@booking_session[:selected_slot]}")

    current_tenant.appointments.create(
      customer: @customer,
      user: current_user || @customer, # Fallback for public bookings
      studio_location: @studio_location,
      service_tier: @service_tier,
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
  end

  def process_payment
    # Initialize Paystack payment
    payment_service = PaystackPaymentService.new(@appointment)

    if payment_service.initialize_payment
      redirect_to payment_service.authorization_url
    else
      @appointment.update(status: 'cancelled')
      redirect_to booking_path, alert: 'Payment initialization failed. Please try again.'
    end
  end

  def handle_paystack_callback
    reference = params[:reference]

    if reference.present?
      payment_service = PaystackPaymentService.new

      if payment_service.verify_payment(reference)
        appointment = current_tenant.appointments.find_by(
          metadata: { paystack_reference: reference }
        )

        if appointment
          appointment.update!(
            payment_status: 'paid',
            status: 'confirmed',
            paid_amount: appointment.price
          )

          # Send confirmation email
          AppointmentConfirmationJob.perform_async(appointment.id)

          redirect_to booking_confirmation_path(appointment.id),
                      notice: 'Booking confirmed! Check your email for details.'
        else
          redirect_to booking_path, alert: 'Appointment not found.'
        end
      else
        redirect_to booking_path, alert: 'Payment verification failed.'
      end
    else
      redirect_to booking_path, alert: 'Invalid payment reference.'
    end
  end

  def customer_params
    params.require(:customer).permit(
      :first_name, :last_name, :email, :phone,
      :address, :city, :state, :zip_code, :notes
    )
  end

  def appointment_params
    params.require(:appointment).permit(:notes, :special_requirements)
  end
end
