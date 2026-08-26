package com.acefuel.loyalty.ui.admin.settlements

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [AdminSettlementsApi] into [ApiResult] via the shared [apiCall] helper. */
class AdminSettlementsRepository(
    private val api: AdminSettlementsApi,
    private val json: Json,
) {
    suspend fun list(
        from: String? = null,
        to: String? = null,
        fuelPumpId: Long? = null,
        status: String? = null,
        query: String? = null,
    ): ApiResult<AdminSettlementListResponse> =
        apiCall(json) { api.list(from = from, to = to, fuelPumpId = fuelPumpId, status = status, query = query) }

    suspend fun show(id: Long): ApiResult<AdminSettlementDto> =
        apiCall(json) { api.show(id) }

    suspend fun reconcile(id: Long): ApiResult<AdminSettlementDto> =
        apiCall(json) { api.reconcile(id) }
}
