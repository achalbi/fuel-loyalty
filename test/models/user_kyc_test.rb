require "test_helper"

class UserKycTest < ActiveSupport::TestCase
  def operator(**attrs)
    User.new({ name: "Op", username: "op#{rand(100000)}", phone_number: "9#{rand(100000000..999999999)}",
               role: :staff, password: "password123" }.merge(attrs))
  end

  test "aadhaar is stored encrypted and exposes a masked value" do
    user = operator(aadhaar_number: "234123412346")
    assert user.save, user.errors.full_messages.to_sentence
    raw = User.connection.select_value("SELECT aadhaar_number FROM users WHERE id=#{user.id}")
    refute_equal "234123412346", raw, "the raw column must be ciphertext"
    assert_equal "2346", user.aadhaar_last4
    assert_equal "XXXX-XXXX-2346", user.masked_aadhaar_number
    assert user.aadhaar_present?
  end

  test "a bad Verhoeff checksum or non-12-digit Aadhaar is rejected" do
    assert_not operator(aadhaar_number: "234123412347").valid? # bad check digit
    assert_not operator(aadhaar_number: "12345").valid?         # too short
    assert_not operator(aadhaar_number: "abcd12341234").valid?  # non-numeric
    assert operator(aadhaar_number: "2341-2341-2346").valid?, "spaces/dashes are stripped"
  end

  test "aadhaar is optional (KYC may be pending)" do
    assert operator.valid?
  end

  test "profile photo rejects a non-image content type" do
    user = operator
    user.profile_photo.attach(io: StringIO.new("not-an-image"), filename: "x.pdf", content_type: "application/pdf")
    assert_not user.valid?
    assert_includes user.errors[:profile_photo].to_sentence, "JPEG"
  end

  test "an image attachment is accepted and purge_kyc clears aadhaar + id card" do
    user = operator(aadhaar_number: "234123412346")
    user.id_card_photo.attach(io: StringIO.new("img"), filename: "id.jpg", content_type: "image/jpeg")
    assert user.save, user.errors.full_messages.to_sentence
    assert user.id_card_present?

    user.purge_kyc!
    user.reload
    assert_nil user.aadhaar_number
    assert_nil user.aadhaar_last4
    assert_not user.id_card_present?
  end
end
