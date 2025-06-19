# app/mailers/concerns/tenant_mailer_concern.rb
module TenantMailerConcern
  extend ActiveSupport::Concern

  def setup_tenant_mailer(tenant)
    return unless tenant&.mailer_enabled?

    puts "=== SETUP_TENANT_MAILER (SIMPLIFIED) ==="
    puts "Tenant: #{tenant.name}"

    # Set tenant-specific from email
    from_email = tenant.email_settings.dig('from_email') || tenant.email
    from_name = tenant.email_settings.dig('from_name') || tenant.name

    mail.from = "#{from_name} <#{from_email}>"

    # Set reply-to if specified
    if tenant.email_settings.dig('reply_to_email').present?
      mail.reply_to = tenant.email_settings['reply_to_email']
    end

    # Set custom headers for tracking (IMPORTANT: The interceptor uses this!)
    mail.header['X-Tenant-ID'] = tenant.id.to_s
    mail.header['X-Studio-Name'] = tenant.name

    puts "Set tenant headers - ID: #{tenant.id}"
    puts "=== END SETUP ==="
  end

  # Remove the build_smtp_config method since it's now in the interceptor

  def use_tenant_templates?
    @tenant&.email_settings&.dig('use_custom_templates') == true
  end

  def tenant_template_path
    "tenants/#{@tenant.id}/mailer_templates" if use_tenant_templates?
  end
end
