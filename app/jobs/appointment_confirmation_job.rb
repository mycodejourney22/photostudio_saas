class AppointmentConfirmationJob < ApplicationJob
  queue_as :default

  def perform(appointment_id)
    appointment = Appointment.find_by(id: appointment_id)
    return unless appointment

    # Check if we should still send confirmation
    return unless appointment.customer.email.present?
    return unless appointment.tenant.confirmations_enabled?
    return unless appointment.status.in?(['confirmed', 'pending'])

    begin
      # Use TenantMailer instead of AppointmentMailer
      TenantMailer.appointment_confirmation(appointment).deliver_now

      # Log the email sent
      appointment.email_logs.create!(
        email_type: 'confirmation',
        sent_at: Time.current,
        tenant: appointment.tenant,
        recipient_email: appointment.customer.email
      ) if appointment.respond_to?(:email_logs)

      Rails.logger.info "Confirmation email sent for appointment #{appointment_id}"
    rescue => e
      Rails.logger.error "Failed to send confirmation email for appointment #{appointment_id}: #{e.message}"

      # Log the failure
      appointment.email_logs.create!(
        email_type: 'confirmation',
        failed_at: Time.current,
        error_message: e.message,
        tenant: appointment.tenant,
        recipient_email: appointment.customer.email
      ) if appointment.respond_to?(:email_logs)
    end
  end
end
