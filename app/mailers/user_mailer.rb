class UserMailer < ApplicationMailer
  def welcome_email(user, temporary_password)
    @user = user
    @temporary_password = temporary_password
    @login_url = "#{ENV['APP_HOST'] || 'http://localhost:5173'}/login"

    mail(
      to: user.email,
      subject: "Welcome to Clementime - Your Account Details"
    )
  end
end
