class SetupCompletionMailer < ApplicationMailer
  def completed(tenant, owner)
    @tenant = tenant
    @owner = owner
    @dashboard_url = "http://#{@tenant.subdomain}.#{Rails.application.config.host_domain}/dashboard"

    mail(
      to: @owner.email,
      subject: "🎉 #{@tenant.name} setup is complete!"
    )
  end
end
