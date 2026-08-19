package com.acefuel.loyalty.ui.admin.reports

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [ReportsApi] into [ApiResult] via the shared [apiCall] helper. */
class ReportsRepository(
    private val api: ReportsApi,
    private val json: Json,
) {
    suspend fun report(
        dimension: String,
        grain: String,
        startDate: String? = null,
        endDate: String? = null,
        fuelType: String? = null,
        fuelPumpId: Long? = null,
        customerId: Long? = null,
    ): ApiResult<ReportResponse> =
        apiCall(json) { api.report(dimension, grain, startDate, endDate, fuelType, fuelPumpId, customerId) }
}
