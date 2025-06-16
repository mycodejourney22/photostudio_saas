class StaffInvitationMailer < ApplicationMailer
  def invite(staff_member, invited_by)
    @staff_member = staff_member
    @invited_by = invited_by
    @tenant = Current.tenant
    @login_url = "http://#{@tenant.subdomain}.#{Rails.application.config.host_domain}/users/sign_in"

    mail(
      to: @staff_member.email,
      subject: "You've been invited to join #{@tenant.name}"
    )
  end
end
