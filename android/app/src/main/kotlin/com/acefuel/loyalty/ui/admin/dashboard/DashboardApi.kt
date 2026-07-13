package com.acefuel.loyalty.ui.admin.dashboard

import retrofit2.http.GET
import retrofit2.http.Query

/**
 * Admin analytics dashboard endpoint. The shared OkHttp client attaches the
 * bearer token; the base URL ends in "/", so the path is relative. This is a
 * read-only GET (no body) with optional filter query params — `preset` drives
 * the quick-range chip row (today/this_week/this_month/last_month).
 */
interface DashboardApi {

    @GET("api/v1/admin/dashboard")
    suspend fun getDashboard(
        @Query("preset") preset: String? = null,
        @Query("start_date") startDate: String? = null,
        @Query("end_date") endDate: String? = null,
        @Query("segment") segment: String? = null,
        @Query("fuel_type") fuelType: String? = null,
    ): DashboardResponse
}
