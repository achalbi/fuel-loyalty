package com.acefuel.loyalty.ui.settlement

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [SettlementApi] calls into [ApiResult] via the shared [apiCall] helper. */
class SettlementRepository(
    private val api: SettlementApi,
    private val json: Json,
) {
    suspend fun newDraft(fuelPumpId: Long?, businessDate: String?): ApiResult<SettlementDraftResponse> =
        apiCall(json) { api.newDraft(fuelPumpId, businessDate) }

    suspend fun list(businessDate: String? = null, fuelPumpId: Long? = null): ApiResult<SettlementListResponse> =
        apiCall(json) { api.list(businessDate, fuelPumpId) }

    suspend fun show(id: Long): ApiResult<SettlementDetailDto> =
        apiCall(json) { api.show(id) }

    suspend fun create(request: SettlementRequest): ApiResult<SettlementDetailDto> =
        apiCall(json) { api.create(SettlementEnvelope(request)) }

    suspend fun update(id: Long, request: SettlementRequest): ApiResult<SettlementDetailDto> =
        apiCall(json) { api.update(id, SettlementEnvelope(request)) }
}
