require "test_helper"

module Admin
  class ProductsControllerTest < ActionDispatch::IntegrationTest
    test "admin sees the product catalog" do
      sign_in users(:one)
      Product.create!(name: "AdBlue", category: "additive", pack_size: 20, pack_unit: "L", mrp: 1730, selling_price: 1730)

      get admin_products_path

      assert_response :success
      assert_select "h1", text: "Products"
      assert_select "a.nav-link.active[href='#{admin_products_path}']", text: /Products/
      assert_match "AdBlue 20L", response.body
    end

    test "admin can add a product" do
      sign_in users(:one)

      assert_difference -> { Product.count }, 1 do
        post admin_products_path, params: { product: { name: "10W40", category: "oil", pack_size: 900, pack_unit: "ml", mrp: 400, selling_price: 380 } }
      end

      assert_redirected_to admin_products_path
    end

    test "admin add is rejected when selling price exceeds mrp" do
      sign_in users(:one)

      assert_no_difference -> { Product.count } do
        post admin_products_path, params: { product: { name: "Bad", category: "additive", mrp: 100, selling_price: 200 } }
      end

      assert_response :unprocessable_entity
    end

    test "admin can update a product price" do
      sign_in users(:one)
      product = Product.create!(name: "AdBlue", category: "additive", pack_size: 5, pack_unit: "L", mrp: 680, selling_price: 680)

      patch admin_product_path(product), params: { product: { selling_price: 650 } }

      assert_redirected_to admin_products_path
      assert_equal BigDecimal("650"), product.reload.selling_price
    end

    test "admin can delete a product" do
      sign_in users(:one)
      product = Product.create!(name: "Temp", category: "additive", pack_size: 5, pack_unit: "L", mrp: 10, selling_price: 10)

      assert_difference -> { Product.count }, -1 do
        delete admin_product_path(product)
      end

      assert_redirected_to admin_products_path
    end
  end
end
