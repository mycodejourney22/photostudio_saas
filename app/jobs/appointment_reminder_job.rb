class AppointmentReminderJob < ApplicationJob
  queue_as :default

  def perform(appointment_id, reminder_type = '24_hours')
    appointment = Appointment.find_by(id: appointment_id)
    return unless appointment

    # Don't send if appointment was cancelled or completed
    return unless appointment.status.in?(['confirmed', 'pending'])

    # Don't send if already sent this type of reminder
    return if appointment.respond_to?(:email_logs) &&
              appointment.email_logs.exists?(
                email_type: 'reminder',
                metadata: { reminder_type: reminder_type }
              )

    begin
      # Use TenantMailer instead of AppointmentMailer
      TenantMailer.appointment_reminder(appointment, reminder_type).deliver_now

      # Log the email sent
      appointment.email_logs.create!(
        email_type: 'reminder',
        sent_at: Time.current,
        tenant: appointment.tenant,
        recipient_email: appointment.customer.email,
        metadata: { reminder_type: reminder_type }
      ) if appointment.respond_to?(:email_logs)

      Rails.logger.info "#{reminder_type} reminder email sent for appointment #{appointment_id}"
    rescue => e
      Rails.logger.error "Failed to send #{reminder_type} reminder for appointment #{appointment_id}: #{e.message}"
    end
  end
end
