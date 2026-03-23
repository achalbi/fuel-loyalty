class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "no-reply@fuel-loyalty.local")
  layout "mailer"
end
