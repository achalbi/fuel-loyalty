require "securerandom"

class LoyaltyLookupToken
  PURPOSE = "loyalty_lookup".freeze
  EXPIRY = 2.minutes

  def self.generate(phone_number)
    normalized_phone_number = Customer.normalize_phone_number(phone_number)

    verifier.generate(
      {
        phone_number: normalized_phone_number,
        nonce: SecureRandom.hex(8)
      },
      purpose: PURPOSE,
      expires_in: EXPIRY
    )
  end

  def self.verified_phone_number(token)
    return if token.blank?

    payload = verifier.verified(token, purpose: PURPOSE)
    return if payload.blank?

    Customer.normalize_phone_number(payload[:phone_number] || payload["phone_number"])
  end

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end

  private_class_method :verifier
end
