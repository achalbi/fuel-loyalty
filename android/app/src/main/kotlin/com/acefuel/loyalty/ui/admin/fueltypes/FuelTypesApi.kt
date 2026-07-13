package com.acefuel.loyalty.ui.admin.fueltypes

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Fuel Types admin endpoints. The shared OkHttp client attaches the bearer
 * token; the base URL already ends in "/", so paths are relative "api/v1/...".
 * Request bodies use the canonical nested envelope ({"fuel_type":{...}}).
 *
 * Backend: app/controllers/api/v1/admin/fuel_types_controller.rb
 *          app/serializers/api/v1/admin/fuel_type_serializer.rb
 * `code` is never accepted from the client — the model auto-generates it from
 * `name` on first save and it stays fixed thereafter.
 */
interface FuelTypesApi {

    @GET("api/v1/admin/fuel_types")
    suspend fun listFuelTypes(): FuelTypesIndexResponse

    @POST("api/v1/admin/fuel_types")
    suspend fun createFuelType(@Body body: FuelTypeEnvelope): FuelTypeDto

    @PATCH("api/v1/admin/fuel_types/{id}")
    suspend fun updateFuelType(@Path("id") id: Long, @Body body: FuelTypeEnvelope): FuelTypeDto

    @DELETE("api/v1/admin/fuel_types/{id}")
    suspend fun deleteFuelType(@Path("id") id: Long): DeleteFuelTypeResponse
}
