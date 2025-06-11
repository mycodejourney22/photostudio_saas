class AppointmentConfirmationJob < ApplicationJob
  def perform(appointment_id)
    appointment = Appointment.find(appointment_id)

    ActsAsTenant.with_tenant(appointment.tenant) do
      AppointmentMailer.confirmation_email(appointment).deliver_now

      if appointment.customer.phone.present?
        SmsService.send_confirmation(appointment)
      end
    end
  end
end
