# app/services/appointment_mailer_service.rb
class AppointmentMailerService
  attr_reader :tenant, :appointment

  def initialize(appointment)
    @appointment = appointment
    @tenant = appointment.tenant
  end

  def send_confirmation
    return unless should_send_confirmations?

    begin
      AppointmentMailer.confirmation_email(appointment).deliver_now
      log_email_sent('confirmation')
      true
    rescue => e
      log_email_error('confirmation', e)
      false
    end
  end

  def send_reminder(reminder_type = '24_hours')
    return unless should_send_reminders? && reminder_enabled?(reminder_type)

    begin
      AppointmentMailer.reminder_email(appointment, reminder_type).deliver_now
      log_email_sent('reminder', reminder_type)
      mark_reminder_sent(reminder_type)
      true
    rescue => e
      log_email_error('reminder', e)
      false
    end
  end

  def send_feedback_request
    return unless should_send_feedback_requests?
    return unless appointment.completed?
    return if feedback_already_requested?

    begin
      AppointmentMailer.feedback_request_email(appointment).deliver_now
      log_email_sent('feedback_request')
      mark_feedback_requested
      true
    rescue => e
      log_email_error('feedback_request', e)
      false
    end
  end

  def send_status_update(previous_status)
    return unless should_send_confirmations? # Use confirmation setting for status updates

    begin
      AppointmentMailer.status_update_email(appointment, previous_status).deliver_now
      log_email_sent('status_update')
      true
    rescue => e
      log_email_error('status_update', e)
      false
    end
  end

  def schedule_all_notifications
    # Send confirmation immediately if just booked
    if appointment.just_created?
      send_confirmation
    end

    # Schedule reminders based on tenant preferences
    schedule_reminders

    # Schedule feedback request if appointment is completed
    if appointment.completed?
      schedule_feedback_request
    end
  end

  private

  def should_send_confirmations?
    tenant.smtp_configured? &&
    tenant.confirmations_enabled? &&
    appointment.customer.email.present?
  end

  def should_send_reminders?
    tenant.smtp_configured? &&
    tenant.reminders_enabled? &&
    appointment.customer.email.present? &&
    appointment.status.in?(['confirmed', 'pending'])
  end

  def should_send_feedback_requests?
    tenant.smtp_configured? &&
    tenant.feedback_requests_enabled? &&
    appointment.customer.email.present?
  end

  def reminder_enabled?(reminder_type)
    tenant.reminder_schedule[reminder_type] == true
  end

  def feedback_already_requested?
    appointment.email_logs.exists?(email_type: 'feedback_request')
  end

  def schedule_reminders
    tenant.reminder_schedule.each do |reminder_type, enabled|
      next unless enabled

      send_at = calculate_reminder_time(reminder_type)
      next if send_at <= Time.current

      AppointmentReminderJob.set(wait_until: send_at)
                           .perform_later(appointment.id, reminder_type)
    end
  end

  def schedule_feedback_request
    delay_hours = tenant.feedback_delay_hours
    send_at = appointment.completed_at + delay_hours.hours

    AppointmentFeedbackJob.set(wait_until: send_at)
                         .perform_later(appointment.id)
  end

  def calculate_reminder_time(reminder_type)
    case reminder_type
    when '1_week'
      appointment.scheduled_at - 1.week
    when '24_hours'
      appointment.scheduled_at - 24.hours
    when '2_hours'
      appointment.scheduled_at - 2.hours
    else
      appointment.scheduled_at - 24.hours
    end
  end

  def mark_reminder_sent(reminder_type)
    create_email_log('reminder', { reminder_type: reminder_type })
  end

  def mark_feedback_requested
    create_email_log('feedback_request')
  end

  def create_email_log(email_type, metadata = {})
    appointment.email_logs.create!(
      email_type: email_type,
      sent_at: Time.current,
      tenant: tenant,
      recipient_email: appointment.customer.email,
      metadata: metadata
    )
  end

  def log_email_sent(email_type, additional_info = nil)
    message = "Email sent: #{email_type} for appointment #{appointment.id}"
    message += " (#{additional_info})" if additional_info
    Rails.logger.info message

    create_email_log(email_type, { additional_info: additional_info })
  end

  def log_email_error(email_type, error)
    Rails.logger.error "Failed to send #{email_type} email for appointment #{appointment.id}: #{error.message}"

    # You might want to store failed email attempts for retry logic
    appointment.email_logs.create!(
      email_type: email_type,
      sent_at: nil,
      failed_at: Time.current,
      error_message: error.message,
      tenant: tenant,
      recipient_email: appointment.customer.email
    )
  end
end
