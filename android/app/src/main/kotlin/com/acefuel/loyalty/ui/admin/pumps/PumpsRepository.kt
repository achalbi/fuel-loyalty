package com.acefuel.loyalty.ui.admin.pumps

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [PumpsApi] calls into [ApiResult] via the shared [apiCall] helper. */
class PumpsRepository(
    private val api: PumpsApi,
    private val json: Json,
) {
    suspend fun loadPumps(): ApiResult<PumpsIndexResponse> =
        apiCall(json) { api.listPumps() }

    suspend fun loadFuelTypes(): ApiResult<List<FuelTypeDto>> =
        apiCall(json) { api.listFuelTypes().fuelTypes }

    suspend fun createPump(active: Boolean, nozzles: List<NozzleAttributesRequest>): ApiResult<FuelPumpDto> =
        apiCall(json) { api.createPump(FuelPumpEnvelope(FuelPumpRequest(active = active, nozzlesAttributes = nozzles))) }

    suspend fun updatePump(id: Long, active: Boolean, nozzles: List<NozzleAttributesRequest>): ApiResult<FuelPumpDto> =
        apiCall(json) { api.updatePump(id, FuelPumpEnvelope(FuelPumpRequest(active = active, nozzlesAttributes = nozzles))) }

    suspend fun deletePump(id: Long): ApiResult<MessageResponse> =
        apiCall(json) { api.deletePump(id) }

    suspend fun setFeatureEnabled(enabled: Boolean): ApiResult<FeatureSettingsResponse> =
        apiCall(json) {
            api.updateFeatureSettings(FeatureSettingsEnvelope(FeatureSettingsRequest(nozzleFeatureEnabled = enabled)))
        }
}
