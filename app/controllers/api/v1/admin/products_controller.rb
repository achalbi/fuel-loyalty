module Api
  module V1
    module Admin
      # Admin CRUD for the product catalog (JSON mirror of the web
      # Admin::ProductsController). selling_price is the source of truth for
      # deriving ₹ from litres/qty in Daily Settlement (A5).
      class ProductsController < Api::V1::Admin::BaseController
        before_action :set_product, only: %i[update destroy]

        # GET /api/v1/admin/products
        def index
          authorize Product, :index?
          render json: { products: Product.for_settings.map { |p| ProductSerializer.call(p) } }, status: :ok
        end

        # GET /api/v1/admin/products/catalog — flat active list for pickers
        def catalog
          authorize Product, :catalog?
          render json: { catalog: Product.active.ordered.map { |p| ProductSerializer.catalog_entry(p) } }, status: :ok
        end

        # POST /api/v1/admin/products
        def create
          authorize Product, :create?
          product = Product.new(product_params)
          product.save!
          render json: ProductSerializer.call(product), status: :created
        end

        # PATCH/PUT /api/v1/admin/products/:id
        def update
          authorize @product, :update?
          @product.update!(product_params)
          render json: ProductSerializer.call(@product), status: :ok
        end

        # DELETE /api/v1/admin/products/:id
        def destroy
          authorize @product, :destroy?
          if @product.destroy
            render json: { id: @product.id, message: "Product removed successfully." }, status: :ok
          else
            render_error(status: :conflict, code: "delete_restricted",
                         message: @product.errors.full_messages.to_sentence.presence || "This product cannot be removed.")
          end
        end

        private

        def set_product
          @product = Product.find(params[:id])
        end

        def product_params
          resource_params(:product).permit(
            :sl_num, :name, :category, :fuel_type_code, :pack_size, :pack_unit,
            :batch, :mrp, :selling_price, :hsn_code, :track_stock, :active
          )
        end
      end
    end
  end
end
