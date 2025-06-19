class TestMailer < ApplicationMailer
  include TenantMailerConcern

  def smtp_test(tenant)
    @tenant = tenant
    setup_tenant_mailer(@tenant)

    mail(
      to: @tenant.email,
      subject: "SMTP Test - #{@tenant.name}",
      template_name: 'smtp_test'
    )
  end
end
