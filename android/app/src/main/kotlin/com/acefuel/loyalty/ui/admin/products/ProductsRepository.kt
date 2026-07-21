package com.acefuel.loyalty.ui.admin.products

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [ProductsApi] calls into [ApiResult] via the shared [apiCall] helper. */
class ProductsRepository(
    private val api: ProductsApi,
    private val json: Json,
) {
    suspend fun loadProducts(): ApiResult<List<ProductDto>> =
        apiCall(json) { api.listProducts().products }

    suspend fun saveProduct(id: Long?, request: ProductRequest): ApiResult<ProductDto> =
        apiCall(json) {
            if (id == null) api.createProduct(ProductEnvelope(request))
            else api.updateProduct(id, ProductEnvelope(request))
        }

    suspend fun deleteProduct(id: Long): ApiResult<DeleteProductResponse> =
        apiCall(json) { api.deleteProduct(id) }
}
