module Admin
  class ProductsController < BaseController
    before_action :set_product, only: %i[edit update destroy]

    def index
      authorize Product
      load_index_state
    end

    def create
      authorize Product
      @product = Product.new(product_params)

      if @product.save
        redirect_to admin_products_path, notice: "Product added successfully."
      else
        load_index_state(new_product: @product)
        flash.now[:alert] = @product.errors.full_messages.to_sentence
        render :index, status: :unprocessable_entity
      end
    end

    def edit
      authorize @product
    end

    def update
      authorize @product

      if @product.update(product_params)
        redirect_to admin_products_path, notice: "Product updated successfully."
      else
        flash.now[:alert] = @product.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @product

      if @product.destroy
        redirect_to admin_products_path, notice: "Product removed successfully."
      else
        redirect_to admin_products_path, alert: @product.errors.full_messages.to_sentence
      end
    end

    private

    def set_product
      @product = Product.find(params[:id])
    end

    def load_index_state(new_product: Product.new(active: true, track_stock: true, category: "lubricant"))
      @product = new_product
      @products = Product.for_settings
      @fuel_type_options = FuelType.active_options
    end

    def product_params
      params.require(:product).permit(
        :sl_num, :name, :category, :fuel_type_code, :pack_size, :pack_unit,
        :batch, :mrp, :selling_price, :hsn_code, :track_stock, :active
      )
    end
  end
end
