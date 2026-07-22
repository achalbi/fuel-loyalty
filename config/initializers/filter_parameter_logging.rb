# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # A7 — Aadhaar / KYC image params must never hit the logs.
  :aadhaar, :profile_photo, :id_card_photo,
  # PII minimization: redact customer/driver/owner phone numbers from request
  # logs (substring match covers phone_number, driver_phone_number, etc.).
  :phone
]
