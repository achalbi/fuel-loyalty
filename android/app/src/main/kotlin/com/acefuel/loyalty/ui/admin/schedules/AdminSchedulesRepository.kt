package com.acefuel.loyalty.ui.admin.schedules

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/**
 * Push-notification admin operations: schedule CRUD, per-schedule + ad-hoc
 * broadcast, and the lease-guarded scheduler sweep. Each call funnels through
 * [apiCall] so transport / server failures land as a structured [ApiResult].
 */
class AdminSchedulesRepository(
    private val api: AdminSchedulesApi,
    private val json: Json,
) {
    suspend fun list(): ApiResult<List<ScheduleDto>> =
        apiCall(json) { api.listSchedules().schedules }

    suspend fun create(request: ScheduleRequest): ApiResult<ScheduleDto> =
        apiCall(json) { api.createSchedule(ScheduleEnvelope(request)) }

    suspend fun update(id: Long, request: ScheduleRequest): ApiResult<ScheduleDto> =
        apiCall(json) { api.updateSchedule(id, ScheduleEnvelope(request)) }

    suspend fun delete(id: Long): ApiResult<Unit> =
        apiCall(json) { api.deleteSchedule(id) }

    suspend fun sendNow(id: Long): ApiResult<SendNowResponse> =
        apiCall(json) { api.sendNow(id) }

    suspend fun runScheduler(): ApiResult<RunResultDto> =
        apiCall(json) { api.runScheduler() }

    suspend fun sendNotification(title: String, message: String): ApiResult<DeliveryResultDto> =
        apiCall(json) { api.sendNotification(NotificationEnvelope(NotificationRequest(title, message))) }
}
