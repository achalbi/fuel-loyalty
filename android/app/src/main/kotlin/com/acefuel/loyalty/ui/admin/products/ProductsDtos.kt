package com.acefuel.loyalty.ui.admin.products

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Product Catalog admin DTOs (A5).
// Backend: app/controllers/api/v1/admin/products_controller.rb
//          app/serializers/api/v1/admin/product_serializer.rb
// Decimals arrive as strings; optional numeric inputs are sent as strings so a
// blank clears the value (matching the reward-rates convention).
// ============================================================================

// ---- Responses ----

@Serializable
data class ProductsIndexResponse(
    val products: List<ProductDto> = emptyList(),
)

@Serializable
data class ProductDto(
    val id: Long,
    @SerialName("sl_num") val slNum: Int? = null,
    val name: String,
    @SerialName("display_name") val displayName: String = "",
    val category: String,
    @SerialName("fuel_type_code") val fuelTypeCode: String? = null,
    @SerialName("pack_size") val packSize: String? = null,
    @SerialName("pack_unit") val packUnit: String? = null,
    val batch: String? = null,
    val mrp: String? = null,
    @SerialName("selling_price") val sellingPrice: String? = null,
    @SerialName("track_stock") val trackStock: Boolean = true,
    val active: Boolean = true,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
data class DeleteProductResponse(
    val id: Long? = null,
    val message: String? = null,
)

// ---- Requests (canonical nested envelope) ----

@Serializable
data class ProductEnvelope(
    val product: ProductRequest,
)

@Serializable
data class ProductRequest(
    val name: String,
    val category: String,
    @SerialName("fuel_type_code") val fuelTypeCode: String? = null,
    @SerialName("pack_size") val packSize: String? = null,
    @SerialName("pack_unit") val packUnit: String? = null,
    val batch: String? = null,
    val mrp: String? = null,
    @SerialName("selling_price") val sellingPrice: String? = null,
    @SerialName("sl_num") val slNum: String? = null,
    @SerialName("track_stock") val trackStock: Boolean = true,
    val active: Boolean = true,
)
