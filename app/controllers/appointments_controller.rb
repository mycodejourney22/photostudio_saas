# app/controllers/appointments_controller.rb
class AppointmentsController < ApplicationController
  before_action :set_appointment, only: [:show, :edit, :update, :destroy, :confirm, :cancel, :complete]
  load_and_authorize_resource

  def index
    @appointments = current_tenant.appointments
                                 .includes(:customer, :user, :studio)

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

    # Apply session type filter if present
    @appointments = @appointments.where(session_type: params[:session_type]) if params[:session_type].present?

    # Determine the current view
    current_view = params[:view].presence || 'today'

    case current_view
    when 'today'
      setup_today_view
    when 'upcoming'
      setup_upcoming_view
    when 'past'
      setup_past_view
    end

    respond_to do |format|
      format.html
      format.json { render json: AppointmentSerializer.new(@appointments).serializable_hash }
      format.pdf { render_appointments_pdf }
      format.csv { render_appointments_csv }
      format.ics { render_appointments_ics }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: AppointmentSerializer.new(@appointment).serializable_hash }
    end
  end

  def new
    @appointment = current_tenant.appointments.build
    @customers = current_tenant.customers.active.order(:first_name)
    @staff_members = current_tenant.users.joins(:tenant_users)
                                         .where(tenant_users: { role: ['admin', 'staff'] })

    # Pre-fill date if provided
    if params[:date].present?
      @appointment.scheduled_at = Date.parse(params[:date]).change(hour: 9)
    end
  end

  def create
    @appointment = current_tenant.appointments.build(appointment_params)
    @appointment.user = current_user unless @appointment.user_id

    if @appointment.save
      AppointmentConfirmationJob.perform_async(@appointment.id) if defined?(AppointmentConfirmationJob)

      respond_to do |format|
        format.html { redirect_to @appointment, notice: 'Appointment created successfully.' }
        format.json { render json: AppointmentSerializer.new(@appointment).serializable_hash, status: :created }
      end
    else
      @customers = current_tenant.customers.active.order(:first_name)
      @staff_members = current_tenant.users.joins(:tenant_users)
                                           .where(tenant_users: { role: ['admin', 'staff'] })

      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @appointment.errors }, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @customers = current_tenant.customers.active.order(:first_name)
    @staff_members = current_tenant.users.joins(:tenant_users)
                                         .where(tenant_users: { role: ['admin', 'staff'] })
  end

  def update
    if @appointment.update(appointment_params)
      respond_to do |format|
        format.html { redirect_to @appointment, notice: 'Appointment updated successfully.' }
        format.json { render json: AppointmentSerializer.new(@appointment).serializable_hash }
      end
    else
      @customers = current_tenant.customers.active.order(:first_name)
      @staff_members = current_tenant.users.joins(:tenant_users)
                                           .where(tenant_users: { role: ['admin', 'staff'] })

      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @appointment.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @appointment.destroy

    respond_to do |format|
      format.html { redirect_to appointments_path, notice: 'Appointment deleted successfully.' }
      format.json { head :no_content }
    end
  end

  def confirm
    if @appointment.update(status: 'confirmed')
      AppointmentConfirmationJob.perform_async(@appointment.id) if defined?(AppointmentConfirmationJob)

      respond_to do |format|
        format.html { redirect_to @appointment, notice: 'Appointment confirmed.' }
        format.json { render json: { status: 'confirmed' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @appointment, alert: 'Unable to confirm appointment.' }
        format.json { render json: { errors: @appointment.errors }, status: :unprocessable_entity }
      end
    end
  end

  def cancel
    if @appointment.can_be_cancelled? && @appointment.update(status: 'cancelled')
      respond_to do |format|
        format.html { redirect_to appointments_path, notice: 'Appointment cancelled.' }
        format.json { render json: { status: 'cancelled' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @appointment, alert: 'Unable to cancel appointment.' }
        format.json { render json: { error: 'Cannot cancel appointment' }, status: :unprocessable_entity }
      end
    end
  end

  def complete
    if @appointment.update(status: 'completed')
      respond_to do |format|
        format.html { redirect_to @appointment, notice: 'Appointment marked as completed.' }
        format.json { render json: { status: 'completed' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @appointment, alert: 'Unable to complete appointment.' }
        format.json { render json: { errors: @appointment.errors }, status: :unprocessable_entity }
      end
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

  private

  def set_appointment
    @appointment = current_tenant.appointments.find(params[:id])
  end

  def appointment_params
    params.require(:appointment).permit(
      :customer_id, :user_id, :studio_id, :scheduled_at, :duration_minutes,
      :price, :session_type, :notes, :special_requirements, :status
    )
  end

  def setup_today_view
    today_start = Date.current.beginning_of_day
    today_end = Date.current.end_of_day

    @today_appointments = @appointments.where(scheduled_at: today_start..today_end)
                                      # .order(:scheduled_at)

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

    @upcoming_appointments = upcoming_appointments

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

    @past_appointments = past_appointments.order(scheduled_at: :desc)
                                         .page(params[:page])
                                         .per(50) # Paginate past appointments

    @today_count = @appointments.where(scheduled_at: Date.current.beginning_of_day..Date.current.end_of_day).count
    @upcoming_count = @appointments.where('scheduled_at > ?', Date.current.end_of_day).count
    @past_count = past_appointments.count
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
      AppointmentReminderJob.perform_async(appointment.id) if defined?(AppointmentReminderJob)
      reminder_count += 1
    end

    redirect_to appointments_path(view: 'upcoming'),
                notice: "#{reminder_count} reminder emails sent successfully."
  end

  def render_appointments_pdf
    # Implementation for PDF export
    respond_to do |format|
      format.pdf do
        render pdf: "appointments_#{Date.current.strftime('%Y%m%d')}",
               template: 'appointments/export.pdf.erb',
               layout: 'pdf'
      end
    end
  end

  def render_appointments_csv
    # Implementation for CSV export
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Date', 'Time', 'Customer', 'Email', 'Phone', 'Session Type', 'Status', 'Price', 'Studio', 'Notes']

      @appointments.each do |appointment|
        csv << [
          appointment.scheduled_at.strftime('%Y-%m-%d'),
          appointment.scheduled_at.strftime('%H:%M'),
          appointment.customer.full_name,
          appointment.customer.email,
          appointment.customer.phone,
          appointment.session_type,
          appointment.status,
          appointment.price,
          appointment.studio&.name,
          appointment.notes
        ]
      end
    end

    send_data csv_data,
              filename: "appointments_#{Date.current.strftime('%Y%m%d')}.csv",
              type: 'text/csv'
  end

  def render_appointments_ics
    # Implementation for calendar export
    cal = Icalendar::Calendar.new

    @appointments.each do |appointment|
      event = Icalendar::Event.new
      event.dtstart = appointment.scheduled_at
      event.dtend = appointment.scheduled_at + (appointment.duration_minutes || 60).minutes
      event.summary = "#{appointment.session_type.humanize} - #{appointment.customer.full_name}"
      event.description = appointment.notes if appointment.notes.present?
      event.location = appointment.studio&.name if appointment.studio

      cal.add_event(event)
    end

    cal.publish

    send_data cal.to_ical,
              filename: "appointments_#{Date.current.strftime('%Y%m%d')}.ics",
              type: 'text/calendar'
  end
end
