# app/mailers/staff_password_mailer.rb
class StaffPasswordMailer < ApplicationMailer
  def password_setup_instructions(user, tenant, raw_token)
    @user = user
    @tenant = tenant
    @raw_token = raw_token

    # Generate the correct URL with tenant subdomain using the raw token
    if Rails.env.development?
      @reset_url = "http://#{@tenant.subdomain}.localhost:3000/users/password/edit?reset_password_token=#{@raw_token}"
    else
      @reset_url = "https://#{@tenant.subdomain}.#{Rails.application.config.app_domain}/users/password/edit?reset_password_token=#{@raw_token}"
    end

    Rails.logger.info "Generating password reset URL: #{@reset_url}"

    mail(
      to: @user.email,
      subject: "Set up your #{@tenant.name} account password"
    )
  end
end
