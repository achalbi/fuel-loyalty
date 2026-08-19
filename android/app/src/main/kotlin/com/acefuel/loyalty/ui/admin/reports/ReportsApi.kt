package com.acefuel.loyalty.ui.admin.reports

import retrofit2.http.GET
import retrofit2.http.Query

/** E1 admin reports endpoint. Bearer token attached by the shared client. */
interface ReportsApi {
    @GET("api/v1/admin/reports")
    suspend fun report(
        @Query("dimension") dimension: String,
        @Query("grain") grain: String,
        @Query("start_date") startDate: String? = null,
        @Query("end_date") endDate: String? = null,
        @Query("fuel_type") fuelType: String? = null,
        @Query("fuel_pump_id") fuelPumpId: Long? = null,
        @Query("customer_id") customerId: Long? = null,
    ): ReportResponse
}
