class UserMailer < ApplicationMailer
  def welcome_email(user, temporary_password)
    @user = user
    @temporary_password = temporary_password
    login_base = ENV["APP_HOST"] || "http://localhost:5173"
    login_base = "https://#{login_base}" unless login_base.start_with?("http")
    @login_url = "#{login_base}/login?username=#{CGI.escape(user.username)}"

    mail(
      to: user.email,
      subject: "Welcome to Clementime - Your Account Details"
    )
  end
end
