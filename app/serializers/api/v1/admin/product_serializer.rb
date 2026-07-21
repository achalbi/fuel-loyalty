module Api
  module V1
    module Admin
      # Admin product-catalog payload. Decimals -> strings, timestamps ISO-8601,
      # matching the other admin serializers.
      class ProductSerializer
        def self.call(product)
          {
            id: product.id,
            sl_num: product.sl_num,
            name: product.name,
            display_name: product.display_name,
            category: product.category,
            fuel_type_code: product.fuel_type_code,
            pack_size: product.pack_size&.to_s,
            pack_unit: product.pack_unit,
            batch: product.batch,
            mrp: product.mrp&.to_s,
            selling_price: product.selling_price&.to_s,
            hsn_code: product.hsn_code,
            track_stock: product.track_stock?,
            active: product.active?,
            created_at: product.created_at&.iso8601,
            updated_at: product.updated_at&.iso8601,
          }
        end

        # Flat active catalog for settlement / visit pickers.
        def self.catalog_entry(product)
          {
            id: product.id,
            name: product.name,
            display_name: product.display_name,
            category: product.category,
            fuel_type_code: product.fuel_type_code,
            pack_size: product.pack_size&.to_s,
            pack_unit: product.pack_unit,
            selling_price: product.selling_price&.to_s,
          }
        end
      end
    end
  end
end
