class AppointmentFeedbackJob < ApplicationJob
  queue_as :default

  def perform(appointment_id)
    appointment = Appointment.find_by(id: appointment_id)
    return unless appointment&.completed?

    # Don't send if already sent feedback request
    return if appointment.respond_to?(:email_logs) &&
              appointment.email_logs.exists?(email_type: 'feedback_request')

    begin
      # Use TenantMailer instead of AppointmentMailer
      TenantMailer.feedback_request(appointment).deliver_now

      # Log the email sent
      appointment.email_logs.create!(
        email_type: 'feedback_request',
        sent_at: Time.current,
        tenant: appointment.tenant,
        recipient_email: appointment.customer.email
      ) if appointment.respond_to?(:email_logs)

      Rails.logger.info "Feedback request email sent for appointment #{appointment_id}"
    rescue => e
      Rails.logger.error "Failed to send feedback request for appointment #{appointment_id}: #{e.message}"
    end
  end
end
