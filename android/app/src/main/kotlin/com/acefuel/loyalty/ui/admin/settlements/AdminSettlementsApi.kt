package com.acefuel.loyalty.ui.admin.settlements

import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.Path
import retrofit2.http.Query

/** D9 admin settlement console endpoints. Bearer token attached by the client. */
interface AdminSettlementsApi {
    @GET("api/v1/admin/settlements")
    suspend fun list(
        @Query("business_date") businessDate: String? = null,
        @Query("fuel_pump_id") fuelPumpId: Long? = null,
        @Query("status") status: String? = null,
        // Admin-12 — read one FSM's sheets for the day.
        @Query("recorded_by_id") recordedById: Long? = null,
    ): AdminSettlementListResponse

    @GET("api/v1/admin/settlements/{id}")
    suspend fun show(@Path("id") id: Long): AdminSettlementDto

    @PATCH("api/v1/admin/settlements/{id}/reconcile")
    suspend fun reconcile(@Path("id") id: Long): AdminSettlementDto
}
