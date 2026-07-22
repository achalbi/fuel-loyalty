require "test_helper"

module Admin
  class UsersKycControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:one)
      @staff = users(:two)
    end

    test "the operator form is multipart and shows the KYC fields" do
      sign_in @admin
      get new_admin_user_path
      assert_response :success
      assert_select "form[enctype='multipart/form-data']"
      assert_select "textarea[name='user[address]']"
      assert_select "input[name='user[aadhaar_number]']"
      assert_select "input[name='user[profile_photo]'][type='file']"
      assert_select "input[name='user[id_card_photo]'][type='file']"
    end

    test "admin can save address + aadhaar and a blank aadhaar keeps the value" do
      sign_in @admin
      patch admin_user_path(@staff), params: { user: { name: @staff.name, username: @staff.username,
        phone_number: @staff.phone_number, address: "5 Residency Rd", aadhaar_number: "234123412346" } }
      assert_redirected_to admin_users_path
      @staff.reload
      assert_equal "234123412346", @staff.aadhaar_number
      assert_equal "5 Residency Rd", @staff.address

      # a subsequent edit leaving aadhaar blank keeps it
      patch admin_user_path(@staff), params: { user: { name: @staff.name, username: @staff.username,
        phone_number: @staff.phone_number, aadhaar_number: "" } }
      assert_equal "234123412346", @staff.reload.aadhaar_number
    end

    test "reveal shows the full aadhaar and logs the access" do
      @staff.update!(aadhaar_number: "234123412346")
      sign_in @admin
      assert_difference -> { PiiAccessLog.count }, 1 do
        post reveal_aadhaar_admin_user_path(@staff)
      end
      assert_response :success
      assert_select "span.font-monospace", text: "234123412346"
    end

    test "purge clears the KYC" do
      @staff.update!(aadhaar_number: "234123412346")
      sign_in @admin
      delete purge_kyc_admin_user_path(@staff)
      assert_redirected_to admin_user_path(@staff)
      assert_nil @staff.reload.aadhaar_number
    end
  end
end
