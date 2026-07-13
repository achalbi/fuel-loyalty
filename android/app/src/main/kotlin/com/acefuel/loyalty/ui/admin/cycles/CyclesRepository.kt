package com.acefuel.loyalty.ui.admin.cycles

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [CyclesApi] calls into [ApiResult] via the shared [apiCall] helper. */
class CyclesRepository(
    private val api: CyclesApi,
    private val json: Json,
) {
    suspend fun loadCycles(): ApiResult<List<ShiftCycleDto>> =
        apiCall(json) { api.listCycles().shiftCycles }

    suspend fun loadTemplates(): ApiResult<List<ShiftTemplateDto>> =
        apiCall(json) { api.listTemplates().shiftTemplates }

    suspend fun createCycle(
        name: String,
        startsOn: String,
        active: Boolean,
        stepTemplateIds: List<Long>,
    ): ApiResult<ShiftCycleDto> = apiCall(json) {
        api.createCycle(ShiftCycleEnvelope(ShiftCycleRequest(name, startsOn, active, stepTemplateIds)))
    }

    suspend fun updateCycle(
        id: Long,
        name: String,
        startsOn: String,
        active: Boolean,
        stepTemplateIds: List<Long>,
    ): ApiResult<ShiftCycleDto> = apiCall(json) {
        api.updateCycle(id, ShiftCycleEnvelope(ShiftCycleRequest(name, startsOn, active, stepTemplateIds)))
    }

    suspend fun deleteCycle(id: Long): ApiResult<DeleteResponse?> =
        apiCall(json) { api.deleteCycle(id) }

    suspend fun activateCycle(id: Long): ApiResult<ShiftCycleDto> =
        apiCall(json) { api.activateCycle(id, EmptyBody()) }

    suspend fun deactivateCycle(id: Long): ApiResult<ShiftCycleDto> =
        apiCall(json) { api.deactivateCycle(id, EmptyBody()) }
}
