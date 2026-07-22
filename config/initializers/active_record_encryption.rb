# Active Record Encryption (A7 — Aadhaar at rest). Keys come from the
# environment / Secret Manager. PRODUCTION MUST supply real keys — generate them
# with `bin/rails db:encryption:init` and set them via Secret Manager:
#   AR_ENCRYPTION_PRIMARY_KEY, AR_ENCRYPTION_DETERMINISTIC_KEY,
#   AR_ENCRYPTION_KEY_DERIVATION_SALT.
# The dev/test defaults below are NOT secret and must never be used in prod.
encryption = Rails.application.config.active_record.encryption

if Rails.env.production?
  encryption.primary_key = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY")
  encryption.deterministic_key = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY")
  encryption.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT")
else
  encryption.primary_key = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", "dev_only_primary_key_not_for_production_0001")
  encryption.deterministic_key = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", "dev_only_deterministic_key_not_for_prod_0001")
  encryption.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", "dev_only_key_derivation_salt_not_for_prod_01")
end

# Aadhaar is short; keep ciphertext compact and don't emit the unencrypted value.
encryption.support_unencrypted_data = true
