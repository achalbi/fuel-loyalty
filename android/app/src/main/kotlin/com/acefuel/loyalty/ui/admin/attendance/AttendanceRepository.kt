package com.acefuel.loyalty.ui.admin.attendance

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [AttendanceApi] calls into [ApiResult] via the shared [apiCall] helper. */
class AttendanceRepository(
    private val api: AttendanceApi,
    private val json: Json,
) {
    suspend fun loadRuns(
        filter: String,
        startDate: String?,
        endDate: String?,
        page: Int,
    ): ApiResult<AttendanceRunsIndexResponse> =
        apiCall(json) { api.listRuns(filter, startDate, endDate, page) }

    suspend fun loadShiftTemplates(): ApiResult<List<ShiftTemplateDto>> =
        apiCall(json) { api.listShiftTemplates().shiftTemplates }

    suspend fun loadPlanner(shiftTemplateId: Long, startsAt: String?): ApiResult<AttendancePlannerResponse> =
        apiCall(json) { api.planner(shiftTemplateId, startsAt) }

    suspend fun createRun(request: AttendanceRunRequest): ApiResult<AttendanceRunDto> =
        apiCall(json) { api.createRun(AttendanceRunEnvelope(request)) }

    suspend fun showRun(id: Long): ApiResult<AttendanceRunDto> =
        apiCall(json) { api.showRun(id) }

    suspend fun invalidateRun(id: Long): ApiResult<AttendanceRunDto> =
        apiCall(json) { api.invalidateRun(id) }

    suspend fun markValidRun(id: Long): ApiResult<AttendanceRunDto> =
        apiCall(json) { api.markValidRun(id) }

    suspend fun deleteRun(id: Long): ApiResult<AttendanceMessageResponse> =
        apiCall(json) { api.deleteRun(id) }
}
