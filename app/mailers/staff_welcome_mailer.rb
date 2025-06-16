class StaffWelcomeMailer < ApplicationMailer
  def welcome(staff_member, temporary_password)
    @staff_member = staff_member
    @temporary_password = temporary_password
    @tenant = Current.tenant
    @login_url = "http://#{@tenant.subdomain}.#{Rails.application.config.host_domain}/users/sign_in"

    mail(
      to: @staff_member.email,
      subject: "Welcome to #{@tenant.name} - Your account is ready"
    )
  end
end
