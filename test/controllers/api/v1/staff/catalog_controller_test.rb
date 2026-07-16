require "test_helper"

module Api
  module V1
    module Staff
      class CatalogControllerTest < ActionDispatch::IntegrationTest
        # Bearer auth for the native-app API layer (see Api::TokenService).
        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "requires authentication" do
          get api_v1_staff_catalog_path
          assert_response :unauthorized
        end

        test "returns the active fuel types and vehicle kinds with a commercial flag" do
          get api_v1_staff_catalog_path, headers: auth_headers(users(:two))

          assert_response :ok
          body = response.parsed_body

          fuel_codes = body["fuel_types"].map { |option| option["code"] }
          assert_includes fuel_codes, "petrol"
          assert body["fuel_types"].all? { |option| option["label"].present? }

          kinds = body["vehicle_kinds"].index_by { |option| option["code"] }
          assert_includes kinds.keys, "two_wheeler"
          assert_equal false, kinds.fetch("two_wheeler")["commercial"]
          assert kinds.fetch("two_wheeler")["label"].present?
        end

        test "marks commercial vehicle kinds as commercial" do
          VehicleType.find_or_create_by!(code: "lcv") do |vehicle_type|
            vehicle_type.name = "LCV"
            vehicle_type.short_name = "LCV"
            vehicle_type.active = true
          end
          VehicleType.where(code: "lcv").update_all(active: true)

          get api_v1_staff_catalog_path, headers: auth_headers(users(:two))

          assert_response :ok
          kinds = response.parsed_body["vehicle_kinds"].index_by { |option| option["code"] }
          assert_equal true, kinds.fetch("lcv")["commercial"]
        end

        test "excludes inactive fuel types" do
          FuelType.where(code: "diesel").update_all(active: false)

          get api_v1_staff_catalog_path, headers: auth_headers(users(:two))

          assert_response :ok
          fuel_codes = response.parsed_body["fuel_types"].map { |option| option["code"] }
          refute_includes fuel_codes, "diesel"
        end
      end
    end
  end
end
