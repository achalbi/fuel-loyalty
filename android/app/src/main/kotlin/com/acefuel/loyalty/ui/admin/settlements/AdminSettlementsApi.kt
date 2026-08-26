package com.acefuel.loyalty.ui.admin.settlements

import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.Path
import retrofit2.http.Query

/** D9 admin settlement console endpoints. Bearer token attached by the client. */
interface AdminSettlementsApi {
    /**
     * [from]/[to] bound the business dates; either end may stand alone. [q] is
     * the free-text cut over FSM, pump number and notes — what an admin actually
     * remembers about a sheet whose date they have forgotten.
     */
    @GET("api/v1/admin/settlements")
    suspend fun list(
        @Query("business_date") businessDate: String? = null,
        @Query("from") from: String? = null,
        @Query("to") to: String? = null,
        @Query("fuel_pump_id") fuelPumpId: Long? = null,
        @Query("user_id") userId: Long? = null,
        @Query("status") status: String? = null,
        @Query("q") query: String? = null,
    ): AdminSettlementListResponse

    @GET("api/v1/admin/settlements/{id}")
    suspend fun show(@Path("id") id: Long): AdminSettlementDto

    @PATCH("api/v1/admin/settlements/{id}/reconcile")
    suspend fun reconcile(@Path("id") id: Long): AdminSettlementDto
}
