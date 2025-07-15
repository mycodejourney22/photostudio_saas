class UserMailer < ApplicationMailer
  default from: 'noreply@shuttersuites.co'

  def welcome_email(user)
    @user = user
    @tenant = user.tenants.first # or however you want to handle this

    mail(
      to: @user.email,
      subject: 'Welcome to ShutterSuites!'
    )
  end
end
