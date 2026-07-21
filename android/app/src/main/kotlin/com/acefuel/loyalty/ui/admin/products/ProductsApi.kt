package com.acefuel.loyalty.ui.admin.products

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Product Catalog admin endpoints (A5). Bodies use the nested envelope
 * ({"product":{...}}). Backend: api/v1/admin/products_controller.rb.
 */
interface ProductsApi {

    @GET("api/v1/admin/products")
    suspend fun listProducts(): ProductsIndexResponse

    @POST("api/v1/admin/products")
    suspend fun createProduct(@Body body: ProductEnvelope): ProductDto

    @PATCH("api/v1/admin/products/{id}")
    suspend fun updateProduct(@Path("id") id: Long, @Body body: ProductEnvelope): ProductDto

    @DELETE("api/v1/admin/products/{id}")
    suspend fun deleteProduct(@Path("id") id: Long): DeleteProductResponse
}
