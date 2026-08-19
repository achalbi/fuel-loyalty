require "test_helper"

module Api
  module V1
    module Admin
      class UsersControllerTest < ActionDispatch::IntegrationTest
        setup do
          @admin = users(:one)
          @staff = users(:two)
        end

        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        # An inactive admin that sorts *ahead* of every fixture user on the old
        # role -> name order ("Aaa Inactive" < "Admin"), so landing last can only
        # come from the active DESC sort in User.admin_listing.
        def create_inactive_admin
          User.create!(
            name: "Aaa Inactive",
            username: "aaa.inactive",
            phone_number: "9000000099",
            role: :admin,
            active: false,
            password: "password123",
            password_confirmation: "password123"
          )
        end

        test "index lists active users before inactive ones" do
          inactive = create_inactive_admin

          get api_v1_admin_users_path, headers: auth_headers(@admin)

          assert_response :ok
          listed = response.parsed_body["users"]
          ids = listed.map { |user| user["id"] }
          assert_equal inactive.id, ids.last, "inactive users must sort below every active user"
          assert_operator ids.index(@admin.id), :<, ids.index(inactive.id)
          assert_operator ids.index(@staff.id), :<, ids.index(inactive.id)
          assert_equal [ true, true, false ], listed.map { |user| user["active"] }
        end

        test "index still orders active users by role then name" do
          get api_v1_admin_users_path, headers: auth_headers(@admin)

          assert_response :ok
          ids = response.parsed_body["users"].map { |user| user["id"] }
          assert_equal [ @admin.id, @staff.id ], ids
        end

        test "index excludes soft deleted users" do
          @staff.update!(active: false)
          @staff.soft_delete!

          get api_v1_admin_users_path, headers: auth_headers(@admin)

          assert_response :ok
          ids = response.parsed_body["users"].map { |user| user["id"] }
          assert_not_includes ids, @staff.id
        end

        test "staff cannot list users via the admin API" do
          get api_v1_admin_users_path, headers: auth_headers(@staff)

          assert_response :forbidden
        end
      end
    end
  end
end
