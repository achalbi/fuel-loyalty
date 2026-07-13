package com.acefuel.loyalty.ui.admin.shifts

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [ShiftsApi] calls into [ApiResult] via the shared [apiCall] helper. */
class ShiftsRepository(
    private val api: ShiftsApi,
    private val json: Json,
) {
    suspend fun loadShiftTemplates(): ApiResult<List<ShiftTemplateDto>> =
        apiCall(json) { api.listShiftTemplates().shiftTemplates }

    suspend fun createShiftTemplate(
        name: String,
        startTime: String,
        durationHours: Double,
        active: Boolean,
    ): ApiResult<ShiftTemplateDto> =
        apiCall(json) {
            api.createShiftTemplate(
                ShiftTemplateEnvelope(ShiftTemplateRequest(name, startTime, durationHours, active)),
            )
        }

    suspend fun updateShiftTemplate(
        id: Long,
        name: String,
        startTime: String,
        durationHours: Double,
        active: Boolean,
    ): ApiResult<ShiftTemplateDto> =
        apiCall(json) {
            api.updateShiftTemplate(
                id,
                ShiftTemplateEnvelope(ShiftTemplateRequest(name, startTime, durationHours, active)),
            )
        }
}
