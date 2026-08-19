package com.acefuel.loyalty.ui.settlement

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Staff Daily Settlement endpoints. The shared OkHttp client attaches the
 * bearer token; the base URL ends in "/", so paths are relative "api/v1/...".
 * Create/update bodies use the canonical nested envelope ({"settlement":{...}}).
 */
interface SettlementApi {

    @GET("api/v1/staff/settlements/new")
    suspend fun newDraft(
        @Query("fuel_pump_id") fuelPumpId: Long?,
        @Query("business_date") businessDate: String?,
        @Query("shift_template_id") shiftTemplateId: Long? = null,
    ): SettlementDraftResponse

    @GET("api/v1/staff/settlements")
    suspend fun list(
        @Query("business_date") businessDate: String? = null,
        @Query("fuel_pump_id") fuelPumpId: Long? = null,
    ): SettlementListResponse

    @GET("api/v1/staff/settlements/{id}")
    suspend fun show(@Path("id") id: Long): SettlementDetailDto

    @POST("api/v1/staff/settlements")
    suspend fun create(@Body body: SettlementEnvelope): SettlementDetailDto

    @PATCH("api/v1/staff/settlements/{id}")
    suspend fun update(@Path("id") id: Long, @Body body: SettlementEnvelope): SettlementDetailDto
}
