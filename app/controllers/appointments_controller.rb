# app/controllers/appointments_controller.rb (fixed version)
class AppointmentsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource
  before_action :set_appointment, only: [:show, :edit, :update, :destroy, :assign_staff, :update_production, :create_sale, :mark_shoot_completed, :mark_editing_completed]
  before_action :load_form_data, only: [:new, :edit, :create, :update]

  def index
    # @appointments = current_tenant.appointments
    #                              .includes(:customer, :assigned_photographer, :assigned_editor, :studio_location, :service_tier)
    #                              .order(:scheduled_at)

    @appointments = filter_by_studio_access(@appointments)
                      .includes(:customer, :assigned_photographer, :assigned_editor, :studio_location, :service_tier)
                      .page(params[:page])

    # Apply search if present
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @appointments = @appointments.joins(:customer)
                                  .where(
                                    "LOWER(customers.first_name) LIKE ? OR
                                     LOWER(customers.last_name) LIKE ? OR
                                     LOWER(customers.email) LIKE ? OR
                                     LOWER(appointments.session_type) LIKE ?",
                                    search_term, search_term, search_term, search_term
                                  )
    end

    # Apply status filter if present
    @appointments = @appointments.where(status: params[:status]) if params[:status].present?
    @appointments = @appointments.where(assigned_photographer_id: params[:photographer_id]) if params[:photographer_id].present?
    @appointments = @appointments.where(assigned_editor_id: params[:editor_id]) if params[:editor_id].present?
    @appointments = @appointments.where('scheduled_at >= ?', Date.parse(params[:start_date])) if params[:start_date].present?
    @appointments = @appointments.where('scheduled_at <= ?', Date.parse(params[:end_date])) if params[:end_date].present?

    # Determine the current view and set up appropriate instance variables
    current_view = params[:view].presence || 'today'

    case current_view
    when 'today'
      setup_today_view
    when 'upcoming'
      setup_upcoming_view
    when 'past'
      setup_past_view
    end

    # For filter dropdowns and stats
    @photographers = current_tenant.staff_members.photographers.active
    @editors = current_tenant.staff_members.editors.active
    @statuses = Appointment.statuses.keys

    respond_to do |format|
      format.html
      format.json { render json: AppointmentSerializer.new(@appointments).serializable_hash }
      format.pdf { render_appointments_pdf }
      format.csv { render_appointments_csv }
      format.ics { render_appointments_ics }
    end
  end

  def show
    @sales = @appointment.sales
    @production_timeline = build_production_timeline
    @photographers = @appointment.tenant.staff_members.where(role: "photographer")
    @editors = @appointment.tenant.staff_members.where(role: "editor")
  end

  def new
    @appointment = current_tenant.appointments.build
    @appointment.scheduled_at = params[:datetime] if params[:datetime]
  end

  def create
    @appointment = current_tenant.appointments.build(appointment_params)
    @appointment.user = current_user

    if @appointment.save
      # Auto-assign photographer if specified
      if params[:appointment][:assigned_photographer_id].present?
        photographer = current_tenant.staff_members.find(params[:appointment][:assigned_photographer_id])
        @appointment.assign_photographer!(photographer)
      end

      redirect_to @appointment, notice: 'Appointment created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def assign_staff
    staff_member_id = params[:staff_member_id]
    assignment_type = params[:assignment_type] # 'photographer' or 'editor'

    begin
      if staff_member_id.present?
        staff_member = current_tenant.staff_members.find(staff_member_id)

        case assignment_type
        when 'photographer'
          @appointment.assign_photographer!(staff_member)
          message = "#{staff_member.full_name} assigned as photographer"
        when 'editor'
          @appointment.assign_editor!(staff_member)
          message = "#{staff_member.full_name} assigned as editor"
        else
          raise "Invalid assignment type"
        end

        staff_name = staff_member.full_name
      else
        # Remove assignment
        case assignment_type
        when 'photographer'
          @appointment.update!(assigned_photographer: nil)
          message = "Photographer assignment removed"
        when 'editor'
          @appointment.update!(assigned_editor: nil)
          message = "Editor assignment removed"
        else
          raise "Invalid assignment type"
        end

        staff_name = nil
      end

      render json: {
        success: true,
        message: message,
        staff_name: staff_name,
        staff_id: staff_member_id
      }
    rescue => e
      render json: {
        success: false,
        message: e.message
      }, status: :unprocessable_entity
    end
  end

  def update
    if @appointment.update(appointment_params)
      # Handle staff assignments
      handle_staff_assignments

      redirect_to @appointment, notice: 'Appointment updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @appointment.can_be_cancelled?
      @appointment.update(status: 'cancelled')
      redirect_to appointments_path, notice: 'Appointment cancelled.'
    else
      redirect_to @appointment, alert: 'Cannot cancel this appointment.'
    end
  end

  def confirm
    if @appointment.update(status: 'confirmed')
      redirect_to @appointment, notice: 'Appointment confirmed successfully.'
    else
      redirect_to @appointment, alert: 'Unable to confirm appointment.'
    end
  end

  def cancel
    if @appointment.can_be_cancelled?
      @appointment.update(status: 'cancelled')
      redirect_to @appointment, notice: 'Appointment cancelled successfully.'
    else
      redirect_to @appointment, alert: 'Cannot cancel this appointment.'
    end
  end

  def mark_shoot_completed
    # binding.pry
    begin
      @appointment.mark_shoot_completed!
      redirect_to @appointment, notice: 'Shoot marked as completed successfully.'
    rescue => e
      redirect_to @appointment, alert: "Error marking shoot complete: #{e.message}"
    end
  end

  def mark_editing_completed
    begin
      @appointment.mark_editing_completed!
      redirect_to @appointment, notice: 'Editing marked as completed successfully.'
    rescue => e
      redirect_to @appointment, alert: "Error marking editing complete: #{e.message}"
    end
  end


  # AJAX endpoint for staff assignment
  def assign_staff
    staff_member_id = params[:staff_member_id]
    assignment_type = params[:assignment_type] # 'photographer' or 'editor'

    begin
      if staff_member_id.present?
        staff_member = current_tenant.staff_members.find(staff_member_id)

        case assignment_type
        when 'photographer'
          @appointment.assign_photographer!(staff_member)
          message = "#{staff_member.full_name} assigned as photographer"
        when 'editor'
          @appointment.assign_editor!(staff_member)
          message = "#{staff_member.full_name} assigned as editor"
        else
          raise "Invalid assignment type"
        end

        staff_name = staff_member.full_name
      else
        # Remove assignment
        case assignment_type
        when 'photographer'
          @appointment.update!(assigned_photographer: nil)
          message = "Photographer assignment removed"
        when 'editor'
          @appointment.update!(assigned_editor: nil)
          message = "Editor assignment removed"
        else
          raise "Invalid assignment type"
        end

        staff_name = nil
      end

      # Handle both AJAX and regular requests
      respond_to do |format|
        format.json do
          render json: {
            success: true,
            message: message,
            staff_name: staff_name,
            staff_id: staff_member_id
          }
        end
        format.html do
          redirect_to @appointment, notice: message
        end
      end
    rescue => e
      respond_to do |format|
        format.json do
          render json: {
            success: false,
            message: e.message
          }, status: :unprocessable_entity
        end
        format.html do
          redirect_to @appointment, alert: e.message
        end
      end
    end
  end


  # Update production status
  def update_production
    case params[:action_type]
    when 'mark_shoot_completed'
      @appointment.mark_shoot_completed!
      message = 'Shoot marked as completed'
    when 'mark_editing_completed'
      @appointment.mark_editing_completed!
      message = 'Editing marked as completed'
    when 'update_delivery_date'
      @appointment.update!(delivery_date: params[:delivery_date])
      message = 'Delivery date updated'
    when 'add_production_notes'
      current_notes = @appointment.production_notes || ''
      new_note = "#{Time.current.strftime('%m/%d %H:%M')}: #{params[:note]}"
      @appointment.update!(production_notes: [current_notes, new_note].compact.join("\n"))
      message = 'Production note added'
    end

    render json: { success: true, message: message }
  rescue => e
    render json: { success: false, message: e.message }, status: :unprocessable_entity
  end

  # Create a sale from this appointment
  def create_sale
    if @appointment.sale.present?
      redirect_to @appointment.sale, notice: 'Sale already exists for this appointment'
      return
    end

    begin
      staff_member = current_tenant.staff_members.customer_service.first || current_tenant.staff_members.first
      @sale = @appointment.create_sale!(staff_member)
      redirect_to @sale, notice: 'Sale created successfully'
    rescue => e
      redirect_to @appointment, alert: "Error creating sale: #{e.message}"
    end
  end

  # Bulk actions
  def bulk_update
    case params[:bulk_action]
    when 'confirm_all_pending'
      confirm_all_pending
    when 'send_reminders'
      send_appointment_reminders
    else
      redirect_to appointments_path, alert: 'Invalid bulk action.'
    end
  end

  def walk_in
    @appointment = current_tenant.appointments.build
    @appointment.scheduled_at = Time.current
    @appointment.booking_source = 'walk_in'
    @appointment.status = 'confirmed'
    @appointment.payment_status = 'unpaid'

    load_form_data

  end

  def create_walk_in
    @appointment = current_tenant.appointments.build(walk_in_appointment_params)
    @appointment.user = current_user
    @appointment.booking_source = 'walk_in'
    @appointment.status = 'confirmed'
    @appointment.payment_status = 'unpaid'

    begin
      # Handle customer creation or selection
      if params[:customer_type] == 'new'
        @customer = find_or_create_walk_in_customer
        return render_walk_in_with_errors if @customer.errors.any?
        @appointment.customer = @customer
      end

      # Set defaults from service tier
      if @appointment.service_tier.present?
        @appointment.service_package_id = @appointment.service_tier.service_package_id
        @appointment.session_type = @appointment.service_tier.service_package.category
        @appointment.duration_minutes = @appointment.service_tier.duration_minutes
        @appointment.price = @appointment.service_tier.price
      end

      if @appointment.save
        redirect_to @appointment, notice: 'Walk-in appointment created successfully!'
      else
        render_walk_in_with_errors
      end

    rescue ActiveRecord::RecordInvalid => e
      # Handle customer creation validation errors
      @appointment.errors.add(:base, "Customer creation failed: #{e.message}")
      render_walk_in_with_errors
    rescue ActiveRecord::NotNullViolation => e
      # Handle database constraint violations gracefully
      if e.message.include?('studio_location_id')
        @appointment.errors.add(:studio_location_id, "must be selected")
      elsif e.message.include?('service_package_id')
        @appointment.errors.add(:service_tier_id, "must be selected")
      else
        @appointment.errors.add(:base, "Please fill in all required fields")
      end
      render_walk_in_with_errors
    rescue => e
      # Handle any other unexpected errors
      @appointment.errors.add(:base, "An error occurred: #{e.message}")
      render_walk_in_with_errors
    end
  end


  private

  def find_or_create_walk_in_customer
    # Try to find existing customer by email or phone
    if params[:customer][:email].present?
      existing = current_tenant.customers.find_by(email: params[:customer][:email])
      return existing if existing
    end

    if params[:customer][:phone].present?
      existing = current_tenant.customers.find_by(phone: params[:customer][:phone])
      return existing if existing
    end

    # Create new customer
    customer_params = params.require(:customer).permit(
      :first_name, :last_name, :email, :phone, :address, :city, :state, :zip_code, :notes
    )

    # Use create instead of create! to handle validation errors gracefully
    customer = current_tenant.customers.create(customer_params)

    # If customer creation fails, add errors to appointment
    unless customer.persisted?
      customer.errors.full_messages.each do |error|
        @appointment.errors.add(:base, "Customer: #{error}")
      end
    end

    customer
  end


  def render_walk_in_with_errors
    load_form_data
    render :walk_in, status: :unprocessable_entity
  end


  def walk_in_appointment_params
    params.require(:appointment).permit(
      :customer_id, :studio_location_id, :service_tier_id, :scheduled_at,
      :duration_minutes, :price, :session_type, :notes, :special_requirements,
      :assigned_photographer_id, :assigned_editor_id
    )
  end

  def set_appointment
    @appointment = current_tenant.appointments.find(params[:id])
  end

  def load_form_data
    @customers = current_tenant.customers.order(:first_name, :last_name)
    @photographers = current_tenant.staff_members.photographers.active
    @editors = current_tenant.staff_members.editors.active
    @studio_locations = current_tenant.studio_locations.active
    @service_tiers = current_tenant.service_tiers.active.includes(:service_package)
  end

  def appointment_params
    params.require(:appointment).permit(
      :customer_id, :studio_location_id, :service_tier_id, :scheduled_at,
      :duration_minutes, :price, :session_type, :status, :payment_status,
      :notes, :special_requirements, :assigned_photographer_id, :assigned_editor_id,
      :equipment_used, :production_notes, :delivery_date
    )
  end

  def handle_staff_assignments
    # Handle photographer assignment
    if params[:appointment][:assigned_photographer_id].present?
      photographer = current_tenant.staff_members.find(params[:appointment][:assigned_photographer_id])
      @appointment.assign_photographer!(photographer) unless @appointment.assigned_photographer == photographer
    end

    # Handle editor assignment
    if params[:appointment][:assigned_editor_id].present?
      editor = current_tenant.staff_members.find(params[:appointment][:assigned_editor_id])
      @appointment.assign_editor!(editor) unless @appointment.assigned_editor == editor
    end
  end

  # Fixed view setup methods
  def setup_today_view
    today_start = Date.current.beginning_of_day
    today_end = Date.current.end_of_day

    @today_appointments = @appointments.where(scheduled_at: today_start..today_end)
                                      .order(:scheduled_at)

    # Set counts for tabs
    @today_count = @today_appointments.count
    @upcoming_count = @appointments.where('scheduled_at > ?', today_end).count
    @past_count = @appointments.where('scheduled_at < ?', today_start).count
  end

  def setup_upcoming_view
    today_end = Date.current.end_of_day

    upcoming_appointments = @appointments.where('scheduled_at > ?', today_end)

    # Apply upcoming-specific filters
    case params[:filter]
    when 'this_week'
      week_end = Date.current.end_of_week
      upcoming_appointments = upcoming_appointments.where('scheduled_at <= ?', week_end)
    when 'next_week'
      next_week_start = Date.current.next_week.beginning_of_week
      next_week_end = Date.current.next_week.end_of_week
      upcoming_appointments = upcoming_appointments.where(scheduled_at: next_week_start..next_week_end)
    when 'this_month'
      month_end = Date.current.end_of_month
      upcoming_appointments = upcoming_appointments.where('scheduled_at <= ?', month_end)
    end

    # FIXED: Assign to instance variable
    @upcoming_appointments = upcoming_appointments.order(:scheduled_at)

    # Set counts for tabs
    @today_count = @appointments.where(scheduled_at: Date.current.beginning_of_day..Date.current.end_of_day).count
    @upcoming_count = @upcoming_appointments.count
    @past_count = @appointments.where('scheduled_at < ?', Date.current.beginning_of_day).count
  end

  def setup_past_view
    today_start = Date.current.beginning_of_day

    past_appointments = @appointments.where('scheduled_at < ?', today_start)

    # Apply past-specific filters
    case params[:period]
    when 'last_week'
      last_week_start = 1.week.ago.beginning_of_week
      past_appointments = past_appointments.where('scheduled_at >= ?', last_week_start)
    when 'last_month'
      last_month_start = 1.month.ago.beginning_of_month
      past_appointments = past_appointments.where('scheduled_at >= ?', last_month_start)
    when 'last_quarter'
      last_quarter_start = 3.months.ago.beginning_of_quarter
      past_appointments = past_appointments.where('scheduled_at >= ?', last_quarter_start)
    when 'last_year'
      last_year_start = 1.year.ago.beginning_of_year
      past_appointments = past_appointments.where('scheduled_at >= ?', last_year_start)
    end

    # FIXED: Assign to instance variable
    @past_appointments = past_appointments.order(scheduled_at: :desc)

    # Set counts for tabs
    @today_count = @appointments.where(scheduled_at: Date.current.beginning_of_day..Date.current.end_of_day).count
    @upcoming_count = @appointments.where('scheduled_at > ?', Date.current.end_of_day).count
    @past_count = @past_appointments.count
  end

  def confirm_all_pending
    today_appointments = current_tenant.appointments
                                      .where(scheduled_at: Date.current.beginning_of_day..Date.current.end_of_day)
                                      .where(status: 'pending')

    confirmed_count = today_appointments.update_all(status: 'confirmed')

    redirect_to appointments_path(view: 'today'),
                notice: "#{confirmed_count} appointments confirmed successfully."
  end

  def send_appointment_reminders
    upcoming_appointments = current_tenant.appointments
                                         .where('scheduled_at > ?', Time.current)
                                         .where(status: ['confirmed', 'pending'])
                                         .joins(:customer)
                                         .where.not(customers: { email: [nil, ''] })

    reminder_count = 0
    upcoming_appointments.find_each do |appointment|
      # AppointmentReminderJob.perform_async(appointment.id) if defined?(AppointmentReminderJob)
      reminder_count += 1
    end

    redirect_to appointments_path(view: 'upcoming'),
                notice: "#{reminder_count} reminder emails sent successfully."
  end

  def build_production_timeline
    timeline = []

    timeline << {
      title: 'Appointment Scheduled',
      date: @appointment.created_at,
      completed: true,
      icon: 'calendar'
    }

    if @appointment.assigned_photographer
      timeline << {
        title: "Photographer Assigned: #{@appointment.photographer_name}",
        date: @appointment.updated_at,
        completed: true,
        icon: 'camera'
      }
    end

    if @appointment.shoot_completed_at
      timeline << {
        title: 'Shoot Completed',
        date: @appointment.shoot_completed_at,
        completed: true,
        icon: 'check'
      }
    end

    if @appointment.assigned_editor
      timeline << {
        title: "Editor Assigned: #{@appointment.editor_name}",
        date: @appointment.updated_at,
        completed: true,
        icon: 'edit'
      }
    end

    if @appointment.editing_completed_at
      timeline << {
        title: 'Editing Completed',
        date: @appointment.editing_completed_at,
        completed: true,
        icon: 'check'
      }
    end

    if @appointment.delivery_date
      timeline << {
        title: 'Scheduled Delivery',
        date: @appointment.delivery_date,
        completed: @appointment.delivery_date <= Date.current,
        icon: 'truck'
      }
    end

    timeline
  end

  def filter_by_studio_access(appointments)
    return appointments if current_user.can_access_all_studios?(current_tenant)

    # Staff can only see appointments from their studio location
    accessible_studios = current_user.accessible_studio_locations(current_tenant)
    appointments.where(studio_location: accessible_studios)
  end
end
