# config/initializers/tenant_mail_interceptor.rb
class TenantMailInterceptor
  def self.delivering_email(mail)
    # Get tenant ID from mail headers
    tenant_id = mail.header['X-Tenant-ID']&.value
    return unless tenant_id

    # Find the tenant
    tenant = Tenant.find_by(id: tenant_id)
    return unless tenant&.smtp_configured?

    # Build SMTP config for this tenant
    smtp_config = build_smtp_config_for_tenant(tenant)
    return unless smtp_config.present?

    puts "=== MAIL INTERCEPTOR DEBUG ==="
    puts "Intercepting email for tenant: #{tenant.name}"
    puts "Applying SMTP config: #{smtp_config.inspect}"

    # Apply tenant-specific SMTP settings to this mail
    mail.delivery_method(:smtp, smtp_config)

    puts "Mail delivery method updated"
    puts "=== END INTERCEPTOR DEBUG ==="
  end

  private

  def self.build_smtp_config_for_tenant(tenant)
    smtp_settings = tenant.smtp_settings
    return nil unless smtp_settings['host'].present?

    config = {
      address: smtp_settings['host'],
      port: smtp_settings['port']&.to_i || 587,
      domain: smtp_settings['domain'] || tenant.full_domain,
      authentication: smtp_settings['authentication'] || 'plain',
      enable_starttls_auto: smtp_settings['enable_starttls_auto'] != false
    }

    # Add credentials if provided
    if smtp_settings['username'].present?
      config[:user_name] = smtp_settings['username']
    end

    if smtp_settings['password'].present?
      config[:password] = smtp_settings['password']
    end

    # Add SSL/TLS configuration
    if smtp_settings['ssl']
      config[:ssl] = true
      config[:port] = 465 if config[:port] == 587
    end

    config
  end
end

# Register the interceptor
ActionMailer::Base.register_interceptor(TenantMailInterceptor)
