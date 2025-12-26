class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Clementime <onboarding@resend.dev>")
  layout "mailer"
end
