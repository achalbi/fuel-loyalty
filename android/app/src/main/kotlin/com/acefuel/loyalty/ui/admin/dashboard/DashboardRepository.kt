package com.acefuel.loyalty.ui.admin.dashboard

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [DashboardApi] calls into [ApiResult] via the shared [apiCall] helper. */
class DashboardRepository(
    private val api: DashboardApi,
    private val json: Json,
) {
    suspend fun loadDashboard(
        preset: String? = null,
        startDate: String? = null,
        endDate: String? = null,
        segment: String? = null,
        fuelType: String? = null,
    ): ApiResult<DashboardResponse> =
        apiCall(json) { api.getDashboard(preset, startDate, endDate, segment, fuelType) }
}
