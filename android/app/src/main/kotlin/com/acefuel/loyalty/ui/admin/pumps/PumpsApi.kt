package com.acefuel.loyalty.ui.admin.pumps

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Fuel Pumps admin endpoints. The shared OkHttp client attaches the bearer
 * token; the base URL already ends in "/", so paths are relative "api/v1/...".
 * Request bodies use the canonical nested envelope ({"fuel_pump":{...}} /
 * {"reward_setting":{...}}).
 */
interface PumpsApi {

    @GET("api/v1/admin/fuel_pumps")
    suspend fun listPumps(): PumpsIndexResponse

    @POST("api/v1/admin/fuel_pumps")
    suspend fun createPump(@Body body: FuelPumpEnvelope): FuelPumpDto

    @PATCH("api/v1/admin/fuel_pumps/{id}")
    suspend fun updatePump(@Path("id") id: Long, @Body body: FuelPumpEnvelope): FuelPumpDto

    @DELETE("api/v1/admin/fuel_pumps/{id}")
    suspend fun deletePump(@Path("id") id: Long): MessageResponse

    @PATCH("api/v1/admin/fuel_pumps/feature_settings")
    suspend fun updateFeatureSettings(@Body body: FeatureSettingsEnvelope): FeatureSettingsResponse

    @GET("api/v1/admin/fuel_types")
    suspend fun listFuelTypes(): FuelTypesResponse
}
