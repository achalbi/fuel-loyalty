require "test_helper"

module Api
  module V1
    module Admin
      class ProductsControllerTest < ActionDispatch::IntegrationTest
        def auth_headers(user)
          { "Authorization" => "Bearer #{Api::TokenService.encode_access(user)}" }
        end

        test "index lists products for an admin" do
          Product.create!(name: "AdBlue", category: "additive", pack_size: 20, pack_unit: "L", mrp: 1730, selling_price: 1730)

          get api_v1_admin_products_path, headers: auth_headers(users(:one))

          assert_response :ok
          assert_includes response.parsed_body["products"].map { |p| p["name"] }, "AdBlue"
        end

        test "catalog returns the active picker list" do
          Product.create!(name: "AdBlue", category: "additive", pack_size: 20, pack_unit: "L", mrp: 1730, selling_price: 1730)

          get catalog_api_v1_admin_products_path, headers: auth_headers(users(:one))

          assert_response :ok
          assert response.parsed_body["catalog"].is_a?(Array)
        end

        test "admin can create a product" do
          assert_difference -> { Product.count }, 1 do
            post api_v1_admin_products_path,
              params: { product: { name: "10W40", category: "oil", pack_size: 900, pack_unit: "ml", mrp: 400, selling_price: 380 } },
              headers: auth_headers(users(:one)), as: :json
          end

          assert_response :created
          assert_equal "10W40", response.parsed_body["name"]
        end

        test "create rejects selling price above mrp with 422" do
          post api_v1_admin_products_path,
            params: { product: { name: "Bad", category: "additive", mrp: 100, selling_price: 200 } },
            headers: auth_headers(users(:one)), as: :json

          assert_response :unprocessable_entity
        end

        test "staff cannot manage the catalog" do
          get api_v1_admin_products_path, headers: auth_headers(users(:two))
          assert_response :forbidden
        end
      end
    end
  end
end
