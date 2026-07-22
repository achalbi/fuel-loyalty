require "test_helper"

module Api
  module V1
    module Admin
      class UsersControllerKycTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "create accepts address + aadhaar and the serializer masks by default" do
          post api_v1_admin_users_path, params: {
            user: { name: "New Op", username: "newop", phone_number: "9012309999", role: "staff",
                    password: "password123", password_confirmation: "password123",
                    address: "12 MG Road", aadhaar_number: "234123412346" },
          }, headers: auth_headers(@admin)

          assert_response :created
          body = response.parsed_body
          assert_equal "12 MG Road", body["address"]
          assert_equal true, body["aadhaar_present"]
          assert_equal "XXXX-XXXX-2346", body["aadhaar_masked"]
          assert_nil body["aadhaar_number"], "the full Aadhaar must never appear in the default serializer"
          assert_equal "234123412346", User.find(body["id"]).aadhaar_number
        end

        test "a bad Aadhaar checksum is rejected 422" do
          post api_v1_admin_users_path, params: {
            user: { name: "Bad", username: "badop", phone_number: "9012308888", role: "staff",
                    password: "password123", password_confirmation: "password123", aadhaar_number: "234123412347" },
          }, headers: auth_headers(@admin)
          assert_response :unprocessable_entity
        end

        test "multipart upload attaches images and a blank aadhaar on edit keeps the stored value" do
          @staff.update!(aadhaar_number: "234123412346")
          image = fixture_file_upload("sample.png", "image/png")
          patch api_v1_admin_user_path(@staff), params: {
            user: { address: "New Address", aadhaar_number: "", profile_photo: image },
          }, headers: auth_headers(@admin)

          assert_response :ok
          @staff.reload
          assert @staff.profile_photo.attached?
          assert_equal "234123412346", @staff.aadhaar_number, "a blank aadhaar keeps the stored value"
          assert_equal "New Address", @staff.address
        end

        test "kyc_reveal returns the full aadhaar to an admin and writes an audit row" do
          @staff.update!(aadhaar_number: "234123412346")
          assert_difference -> { PiiAccessLog.count }, 1 do
            get kyc_reveal_api_v1_admin_user_path(@staff), headers: auth_headers(@admin)
          end
          assert_response :ok
          assert_equal "234123412346", response.parsed_body["aadhaar_number"]
          log = PiiAccessLog.last
          assert_equal @admin.id, log.actor_user_id
          assert_equal @staff.id, log.target_user_id
        end

        test "staff cannot reveal KYC" do
          get kyc_reveal_api_v1_admin_user_path(@staff), headers: auth_headers(@staff)
          assert_response :forbidden
        end

        test "purge clears aadhaar and returns the masked serializer" do
          @staff.update!(aadhaar_number: "234123412346")
          delete kyc_api_v1_admin_user_path(@staff), headers: auth_headers(@admin)
          assert_response :ok
          assert_equal false, response.parsed_body["aadhaar_present"]
          assert_nil @staff.reload.aadhaar_number
        end
      end
    end
  end
end
