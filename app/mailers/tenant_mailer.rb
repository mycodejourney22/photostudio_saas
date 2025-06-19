class TenantMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM_EMAIL', 'noreply@photostudio.com')

  def verification_email(tenant)
    @tenant = tenant

    @verification_url = tenant_registration_verify_url(
      token: @tenant.verification_token,
      host: Rails.application.config.main_domain || 'localhost:3000'
    )

    mail(
      to: @tenant.email,
      subject: "Welcome to PhotoStudio Pro - Verify Your Studio"
    )
  end

  def welcome_email(tenant)
    @tenant = tenant
    @studio_url = "https://#{@tenant.subdomain}.#{Rails.application.config.app_domain}"

    mail(
      to: @tenant.email,
      subject: "Your PhotoStudio Pro account is ready!"
    )
  end

def appointment_confirmation(appointment)
  @appointment = appointment
  @customer = appointment.customer
  @tenant = appointment.tenant
  @service_tier = appointment.service_tier
  @service_package = appointment.service_package || @service_tier&.service_package
  @studio_location = appointment.studio_location

  mail(
    to: @customer.email,
    subject: "#{@tenant.name} - Appointment Confirmed for #{@appointment.scheduled_at.strftime('%B %d, %Y')}",
    from: @tenant.email
  )
end

def appointment_reminder(appointment, reminder_type = '24_hours')
  @appointment = appointment
  @customer = appointment.customer
  @tenant = appointment.tenant
  @service_tier = appointment.service_tier
  @service_package = appointment.service_package || @service_tier&.service_package
  @studio_location = appointment.studio_location
  @reminder_type = reminder_type

  subject_text = case reminder_type
  when '1_week' then "Your session is next week"
  when '24_hours' then "Your session is tomorrow!"
  when '2_hours' then "Your session starts soon"
  else "Session reminder"
  end

  mail(
    to: @customer.email,
    subject: "#{@tenant.name} - #{subject_text}",
    from: @tenant.email
  )
end

def feedback_request(appointment)
  @appointment = appointment
  @customer = appointment.customer
  @tenant = appointment.tenant
  @service_tier = appointment.service_tier
  @service_package = appointment.service_package || @service_tier&.service_package

  mail(
    to: @customer.email,
    subject: "How was your experience with #{@tenant.name}?",
    from: @tenant.email
  )
end
end
