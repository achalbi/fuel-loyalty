class AddKycFieldsToUsers < ActiveRecord::Migration[8.1]
  # A7 — operator KYC profile fields (Q3: profile-fields-only, no OTP). `address`
  # is free-form; `aadhaar_number` holds Active-Record-Encryption ciphertext (the
  # model exposes the plaintext virtual value); `aadhaar_last4` is the plaintext
  # tail for masked display without decrypting. Profile/ID-card photos are
  # ActiveStorage attachments. See docs/acefuels/17-spec-operator-kyc.md.
  def change
    change_table :users, bulk: true do |t|
      t.text :address
      t.text :aadhaar_number        # ciphertext at rest (encrypts :aadhaar_number)
      t.string :aadhaar_last4, limit: 4
    end
  end
end
