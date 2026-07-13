package com.acefuel.loyalty.ui.admin.vehicletypes

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

/** Retrofit surface for admin vehicle-type CRUD (self-contained to this feature). */
interface VehicleTypesApi {

    @GET("api/v1/admin/vehicle_types")
    suspend fun list(): VehicleTypesListResponse

    @POST("api/v1/admin/vehicle_types")
    suspend fun create(@Body body: VehicleTypeEnvelope): VehicleTypeDto

    @PATCH("api/v1/admin/vehicle_types/{id}")
    suspend fun update(@Path("id") id: Long, @Body body: VehicleTypeEnvelope): VehicleTypeDto

    @DELETE("api/v1/admin/vehicle_types/{id}")
    suspend fun delete(@Path("id") id: Long): VehicleTypeDeleteResponse
}
