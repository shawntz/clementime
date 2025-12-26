class UserMailer < ApplicationMailer
  def welcome_email(user, reset_token)
    @user = user
    app_base = ENV["APP_HOST"] || "http://localhost:5173"
    app_base = "https://#{app_base}" unless app_base.start_with?("http")
    @reset_url = "#{app_base}/reset-password?token=#{reset_token}"
    @login_url = "#{app_base}/login?username=#{CGI.escape(user.username)}"

    # Get super admin email for CC
    super_admin_email = SystemConfig.get("super_admin_email", "")

    mail_options = {
      to: user.email,
      subject: "Welcome to Clementime - Set Your Password"
    }

    # Add CC if super admin email is configured
    mail_options[:cc] = super_admin_email if super_admin_email.present?

    mail(mail_options)
  end

  def password_reset(user)
    @user = user
    app_base = ENV["APP_HOST"] || "http://localhost:5173"
    app_base = "https://#{app_base}" unless app_base.start_with?("http")
    @reset_url = "#{app_base}/reset-password?token=#{user.reset_password_token}"

    mail(
      to: user.email,
      subject: "Password Reset Request - Clementime"
    )
  end
end
