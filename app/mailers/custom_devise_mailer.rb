# app/mailers/custom_devise_mailer.rb
class CustomDeviseMailer < Devise::Mailer
    helper :application
    include Devise::Controllers::UrlHelpers
    default template_path: 'devise/mailer'
  
    def reset_password_instructions(record, token, opts = {})
      tenant = record.tenants.first # or however you associate user ↔ tenant
      return super unless tenant # fallback if no tenant found
  
      host = Rails.env.production? ? "#{tenant.subdomain}.shuttersuites.co" : "#{tenant.subdomain}.localhost:3000"
      opts[:host] = host
      opts[:protocol] = 'https'
  
      # Generate full URL manually for safety
      full_url = edit_user_password_url(reset_password_token: token, host: host, protocol: 'https')
  
      @reset_password_url = full_url

      super(record, token, opts)   
    end
  end
  