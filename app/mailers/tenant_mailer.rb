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
end
