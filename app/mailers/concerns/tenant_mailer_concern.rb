# app/mailers/concerns/tenant_mailer_concern.rb
module TenantMailerConcern
  extend ActiveSupport::Concern

  private

  def setup_tenant_mailer(tenant)
    return unless tenant&.mailer_enabled? && tenant.smtp_settings.present?

    # Set tenant-specific SMTP settings
    smtp_config = build_smtp_config(tenant)
    mail.delivery_method.settings.merge!(smtp_config) if smtp_config.present?

    # Set tenant-specific from email
    from_email = tenant.email_settings.dig('from_email') || tenant.email
    from_name = tenant.email_settings.dig('from_name') || tenant.name

    mail.from = "#{from_name} <#{from_email}>"

    # Set reply-to if specified
    if tenant.email_settings.dig('reply_to_email').present?
      mail.reply_to = tenant.email_settings['reply_to_email']
    end

    # Set custom headers for tracking
    mail.header['X-Tenant-ID'] = tenant.id.to_s
    mail.header['X-Studio-Name'] = tenant.name
  end

  def build_smtp_config(tenant)
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

  def use_tenant_templates?
    @tenant&.email_settings&.dig('use_custom_templates') == true
  end

  def tenant_template_path
    "tenants/#{@tenant.id}/mailer_templates" if use_tenant_templates?
  end
end
